using JuMP, Ipopt

function kappa(j::Int, SS::Array{Server_Setting}, WS::Array{Workload_Setting})
    # calculate aggregated SCV
    tempv = [1/WS[i].mean_jobsize for i in 1:length(WS)]
    μ_min = minimum(tempv)
    num = 0.0
    denom = 0.0
    for i in 1:length(WS)
      num += (1/WS[i].mean_inter_arrival)*(std(WS[i].dist_inter_arrival)/WS[i].mean_inter_arrival)^2
      denom += (1/WS[i].mean_inter_arrival)
    end

    for ws in WS
      num += (1/ws.mean_inter_arrival)*(std(ws.dist_inter_arrival)/ws.mean_inter_arrival)^2
      denom += (1/ws.mean_inter_arrival)
    end

    agg_scv = num/denom

    return (-log(SS[j].ϵ)*max(1,agg_scv))/(μ_min*SS[j].δ)
end

function solveCentralized(SS::Array{Server_Setting}, WS::Array{Workload_Setting}, _S::Array{Server}, use_kappa::Bool=false)
    S = 1:length(SS)
    A = 1:length(WS)

    # Declare a model
    m = Model(solver = IpoptSolver(max_iter=9999999, tol=1.0))

    # Set variables
    @variable(m, y[i = A, j = S] >= 0)
    @variable(m, x[j = S])
    for j in S
      setlowerbound(x[j], SS[j].γ)
      setupperbound(x[j], SS[j].Γ)
    end

    for i in A
        for j in S
            if !in(i, SS[j].Apps)
              setlowerbound(y[i,j],0)
              setupperbound(y[i,j],0)
            end
        end
    end

    # Set objective function
    @NLobjective(m, Min, sum(SS[j].K + SS[j].α*x[j]^SS[j].n for j in S))

    ## Add constraints

    # Nonlinear constraint (chance constraint)
    for j in S
        @NLexpression(m, expr1, sum(y[i,j] for i in SS[j].Apps))
        @NLexpression(m, expr2, sum(1/WS[i].mean_jobsize*y[i,j] for i in SS[j].Apps))
        @NLexpression(m, expr_as, sum((WS[i].scv_inter_arrival+WS[i].scv_jobsize)/((1/WS[i].mean_inter_arrival)*WS[i].mean_jobsize)*y[i,j] for i in SS[j].Apps)  )
        @NLexpression(m, expr_s, sum((WS[i].scv_jobsize)/((1/WS[i].mean_inter_arrival)*WS[i].mean_jobsize)*y[i,j] for i in SS[j].Apps))
        @NLconstraint(m, expr1*(-log(SS[j].ϵ)/SS[j].δ)*(expr_as/(1+expr_s)) <= x[j])
    end

    # linear constraint
    for i in A
      aff = AffExpr()
      for j in S
        if in(i, SS[j].Apps) == true
          push!(aff, 1.0, y[i,j])
        end
      end
      @constraint(m, aff == (1/WS[i].mean_inter_arrival)*WS[i].mean_jobsize)
    end

    ## Solve the problem
    #print(m)
    solve(m)
    #println("Obj = $(getobjectivevalue(m))")
    #for i in 1:length(SS) println("x[$i] = $(getvalue(x[i]))") end
    x_solution = [getvalue(x[j]) for j in S]
    y_solution = [[getvalue(y[i,j]) for j in S] for i in A]

    return x_solution, y_solution
end

function solveDistributed(SS)

end

#=
function solveCentralized(SS::Array{Server_Setting}, WS::Array{Workload_Setting}, _S::Array{Server})
    S = 1:length(SS)
    A = 1:length(WS)

    # Declare a model
    m = Model(solver = IpoptSolver())

    # Set variables
    @variable(m, y[i = A, j = S] >= 0)
    @variable(m, x[j = S])
    for j in S
      setlowerbound(x[j], SS[j].γ)
      setupperbound(x[j], SS[j].Γ)
    end

    for i in A
        for j in S
            if !in(i, SS[j].Apps)
              setlowerbound(y[i,j],0)
              setupperbound(y[i,j],0)
            end
        end
    end

    # Set objective function
    @NLobjective(m, Min, sum(SS[j].K + SS[j].α*x[j]^SS[j].n for j in S))

    ## Add constraints
    for j in S
      aff = AffExpr()
      for i in A
        if in(i,SS[j].Apps) == true
          push!(aff, 1.0, y[i,j])
        end
      end
      @constraint(m, aff + _S[j].κ  <= x[j])
    end

    for i in A
      aff = AffExpr()
      for j in S
        if in(i, SS[j].Apps) == true
          push!(aff, 1.0, y[i,j])
        end
      end
      #@constraint(m, aff == WS[i].instant_demand)
      @constraint(m, aff == (1/WS[i].mean_inter_arrival)*WS[i].mean_jobsize)
    end

    ## Solve the problem
    #print(m)
    solve(m)
    #println("Obj = $(getobjectivevalue(m))")
    #for i in 1:length(SS) println("x[$i] = $(getvalue(x[i]))") end
    x_solution = [getvalue(x[j]) for j in S]
    y_solution = [[getvalue(y[i,j]) for j in S] for i in A]

    return x_solution, y_solution
end
=#
