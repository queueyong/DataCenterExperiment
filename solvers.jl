using JuMP, Ipopt, CPLEX

function solveDistributed(SS)

end

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
