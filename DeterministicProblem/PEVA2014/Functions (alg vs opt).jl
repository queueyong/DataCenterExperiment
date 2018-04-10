using JuMP, Ipopt
using CPLEX

# function definitions
function server_power(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return SS[j].K + (SS[j].α)*(S[j].current_speed^SS[j].n)
end

function server_power_1st_diff(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return (SS[j].α)*(SS[j].n)*(S[j].current_speed^(SS[j].n-1))
end

function server_power_2nd_diff(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return (SS[j].α)*(SS[j].n)*((SS[j].n)-1)*(S[j].current_speed^(SS[j].n-2))
end

function x_dot(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  if SS[j].γ < S[j].current_speed < SS[j].Γ
    return S[j].current_price-server_power_1st_diff(j,SS,S)
  elseif S[j].current_speed == SS[j].Γ
    return min( S[j].current_price - server_power_1st_diff(j,SS,S) , 0.0 )
  elseif S[j].current_speed == SS[j].γ
    return max( S[j].current_price - server_power_1st_diff(j,SS,S) , 0.0 )
  end
end

function p_dot(j::Int64, S::Array{Server})
  if S[j].current_price >= 0.0
    return S[j].κ + S[j].current_remaining_workload - S[j].current_speed
  else
    return max( S[j].κ + S[j].current_remaining_workload - S[j].current_speed , 0.0 )
  end
end

function workload_setter()
  WS = Workload_Setting[]
  push!(WS, Workload_Setting(20.0, "LogNormal",0.25,2.0,sqrt((0.25^2)*2.0),"LogNormal",5.0,1.5,sqrt((5.0^2)*1.5)))
  push!(WS, Workload_Setting(20.0, "LogNormal", 0.5, 1.5, sqrt((0.5^2)*1.5), "LogNormal", 10.0, 2.0, sqrt((10.0^2)*2.0)))
  push!(WS, Workload_Setting(20.0, "Exponential", 0.25, 1.0, sqrt((0.25^2)*1.0), "LogNormal", 5.0, 1.0, sqrt((5.0^2)*1.0)))
  push!(WS, Workload_Setting(20.0, "LogNormal", 0.1, 0.8, sqrt((0.1^2)*0.8), "LogNormal", 2.0, 0.8, sqrt((2.0^2)*0.8)))
  push!(WS, Workload_Setting(15.0, "LogNormal", 0.2, 2.0, sqrt((0.2^2)*2.0),"LogNormal", 3.0,0.5,sqrt((3.0^2)*0.5)))
  return WS
end

function server_setter()
  SS = Server_Setting[]
  push!(SS, Server_Setting(5.0, 100.0, 150.0, 0.3333, 3, 3.0, 0.001, 100.0, 1000.0, (1,)))
  push!(SS, Server_Setting(7.0, 102.0, 250.0, 0.2, 3, 3.0, 0.001, 102.0, 2000.0, (1,)))
  push!(SS, Server_Setting(6.0, 99.0, 220.0, 1.0, 3, 3.0, 0.001, 99.0, 3000.0, (1,2)))
  push!(SS, Server_Setting(5.0, 105.0, 150.0, 0.6667, 3, 3.0, 0.001, 105.0, 1000.0, (1,2,3)))
  push!(SS, Server_Setting(7.0, 100.0, 300.0, 0.8, 3, 3.0, 0.001, 100.0, 2000.0, (2,3)))
  push!(SS, Server_Setting(8.0, 102.0, 350.0, 0.4, 3, 3.0, 0.001, 102.0, 3000.0, (2,3)))
  push!(SS, Server_Setting(6.0, 100.0, 220.0, 0.4286, 3, 3.0, 0.001, 100.0, 1000.0, (3,)))
  push!(SS, Server_Setting(7.0, 105.0, 350.0, 0.5, 3, 3.0, 0.001, 105.0, 2000.0, (4,5)))
  push!(SS, Server_Setting(8.0, 102.0, 400.0, 0.6, 3, 3.0, 0.001, 102.0, 3000.0, (4,5)))
  push!(SS, Server_Setting(10.0, 105.0, 700.0, 0.4444, 3, 3.0, 0.001, 105.0, 1000.0, (5,)))
  return SS
end

function server_creater(SS::Array{Server_Setting}, WS::Array{Workload_Setting})
  #aggreated scv를 먼저 계산
  tempv = Float64[]
  for i in 1:length(WS)
    push!(tempv,WS[i].mean_inter_arrival)
  end
  μ_min = minimum(tempv)

  num = 0.0
  denom = 0.0
  for i in 1:length(WS)
    num += (1/WS[i].mean_inter_arrival)*(WS[i].std_inter_arrival/WS[i].mean_inter_arrival)^2
    denom += (1/WS[i].mean_inter_arrival)
  end
  agg_scv = num/denom

  #서버 객체 생성 및 초기값 설정
  S = Server[]

  for j in 1:length(SS)
    push!(S, Server(SS[j].x_0, SS[j].x_0, SS[j].p_0, SS[j].p_0))
    # with κ
     S[j].κ = (-log(SS[j].ϵ)*max(1,agg_scv))/(μ_min*SS[j].δ)
     #S[j].κ = 23.0259 #wrong kappa value
    # without κ
    # S[j].κ = 0.0
  end
  return S
end

function iterate(SS::Array{Server_Setting}, S::Array{Server}, WS::Array{Workload_Setting}, num_iter::Int64, R::Record)
  iter = 0
  obj = 0.0
  while iter < num_iter
    m = Model(solver = CplexSolver(CPX_PARAM_TUNINGDISPLAY = 0, CPX_PARAM_SCRIND = 0)) # parameter setting: no displaying output
    @variable(m, y[i = 1:length(WS), j = 1:length(SS)] >= 0)
    expr = AffExpr()
    for j in 1:length(SS)
      for i in 1:length(WS)
        if in(i,SS[j].Apps) == true
          push!(expr, S[j].current_price, y[i,j])
        end
      end
    end
    @objective(m, Min, expr)

    for i in 1:length(WS)
      expr = AffExpr()
      for j in 1:length(SS)
        if in(i,SS[j].Apps) == true
          push!(expr, 1.0, y[i,j])
        end
      end
      @constraint(m, expr == WS[i].instant_demand)
    end

    for j in 1:length(SS)
      expr = AffExpr()
      for i in 1:length(SS)
        if in(i, SS[j].Apps) == true
          push!(expr, 1.0, y[i,j])
        end
      end
      @constraint(m, expr <= SS[j].Γ)
    end
    solve(m)

    # Updating current remaining workloads using y[i,j]s
    for j in 1:length(S)
      workloads = 0.0
      for i in 1:length(WS)
        if in(i, SS[j].Apps) == true
          workloads += getvalue(y[i,j])
        end
      end
      S[j].current_remaining_workload = workloads
    end

    for j in 1:length(S)
      # For plotting
      push!(R.speed_array[j], S[j].current_speed)
      push!(R.price_array[j], S[j].current_price)
      obj += server_power(j, SS, S)

      # updating speeds
      S[j].previous_speed = S[j].current_speed
      S[j].current_speed = S[j].previous_speed + (1/server_power_2nd_diff(j, SS, S))*(x_dot(j, SS, S))

      # updating prices
      S[j].previous_price = S[j].current_price
      S[j].current_price = S[j].previous_price + p_dot(j, S)
    end

    push!(R.obj_array, obj)
    obj = 0.0
    iter += 1
  end
end
