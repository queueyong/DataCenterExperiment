# function definitions
function server_power(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return SS[j].K + (SS[j].α)*(S[j].current_speed^SS[j].n)
end

function server_power_1st_diff(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return (SS[j].α)*(SS[j].n)*(S[j].current_speed^((SS[j].n)-1))
end

function server_power_2nd_diff(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return (SS[j].α)*(SS[j].n)*((SS[j].n)-1)*(S[j].current_speed^((SS[j].n)-2))
end

function x_dot(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  if SS[j].γ < S[j].current_speed < SS[j].Γ
    return S[j].current_price - server_power_1st_diff(j,SS,S)
  elseif S[j].current_speed >= SS[j].Γ
    return min( S[j].current_price - server_power_1st_diff(j,SS,S) , 0.0 )
  elseif S[j].current_speed <= SS[j].γ
    return max( S[j].current_price - server_power_1st_diff(j,SS,S) , 0.0 )
  end
end

function p_dot(j::Int64, S::Array{Server})
  if S[j].current_price >= 0.0
    return S[j].κ + S[j].current_remaining_workload - S[j].current_speed
  else
    return max(S[j].κ + S[j].current_remaining_workload - S[j].current_speed, 0.0)
  end
end

function find_min_price_server(app_type::Int64, SS::Array{Server_Setting}, S::Array{Server})
  server_index = 0
  temp_price = typemax(Float64)

  for j in 1:length(SS)
    if in(app_type, SS[j].Apps) == true
      if temp_price > S[j].current_price
        temp_price = S[j].current_price
        server_index = j
      end
    end
  end

  return server_index
end

function next_event(vdc::VirtualDataCenter)
  if vdc.next_regular_update == min(vdc.next_regular_update, vdc.next_arrival, vdc.next_completion)
    inter_event_time = vdc.next_regular_update - vdc.current_time   # 지난이벤트와 지금이벤트의 시간간격을 저장
    vdc.current_time = vdc.next_regular_update                      # 시뮬레이터의 현재 시간을 바꿈
    # remaining_workload 업데이트
    for j in 1:length(vdc.S)   # 모든 서버에 대해
      for i in 1:length(vdc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        vdc.S[j].WIP[i].remaining_workload -= (vdc.S[j].current_speed/length(vdc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        vdc.S[j].current_remaining_workload -= (vdc.S[j].current_speed/length(vdc.S[j].WIP))*inter_event_time  # 서버 j의 workload 총합을 줄여준다.
      end

      # For plotting speed and price
      if vdc.warmed_up == true
          push!(speed_array[j], vdc.S[j].current_speed)
          push!(price_array[j], vdc.S[j].current_price)
      end

      # 스피드 업데이트
      vdc.S[j].previous_speed = vdc.S[j].current_speed
      vdc.S[j].current_speed = (vdc.S[j].previous_speed) + ((1/server_power_2nd_diff(j, vdc.SS, vdc.S))*(x_dot(j, vdc.SS, vdc.S)))

      # price 업데이트
      vdc.S[j].previous_price = vdc.S[j].current_price
      vdc.S[j].current_price = vdc.S[j].previous_price + p_dot(j, vdc.S)
    end

    # completion_time을 계산해야함  (모든 서버들에 대해서 )
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(vdc.S)
      for i in 1:length(vdc.S[j].WIP)
        if shortest_remaining_time > (vdc.S[j].WIP[i].remaining_workload/(vdc.S[j].current_speed/length(vdc.S[j].WIP)))
          shortest_remaining_time = (vdc.S[j].WIP[i].remaining_workload/(vdc.S[j].current_speed/length(vdc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          vdc.next_completion = vdc.current_time + shortest_remaining_time
          vdc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    if server_index_2 == 0 && WIP_index == 0 # 만약 데이터센터 안에 아무 arrival이 없다면
      vdc.next_completion = typemax(Float64)
      vdc.next_regular_update += 0.01
    else
      vdc.next_regular_update += 0.01
    end

  elseif vdc.next_arrival == min(vdc.next_regular_update, vdc.next_arrival, vdc.next_completion)
    inter_event_time = vdc.next_arrival - vdc.current_time   # 지난이벤트와 지금이벤트의 시간간격을 저장
    vdc.current_time = vdc.next_arrival                      # 시뮬레이터의 현재 시간을 바꿈
    println(f,"(Time: $(vdc.current_time)) Current event: New arrival ($(vdc.AI[1].arrival_index)th arrival, app_type: $(vdc.AI[1].app_type), workload: $(vdc.AI[1].remaining_workload), server_dispatched: $(find_min_price_server(vdc.AI[1].app_type, vdc.SS, vdc.S))")

    server_index = find_min_price_server(vdc.AI[1].app_type, vdc.SS, vdc.S)    # 일감의 type에 맞춰서 어느 서버로 보내야할지 결정

    vdc.S[server_index].previous_remaining_workload = vdc.S[server_index].current_remaining_workload  # 기존 remaining_workload 저장
    vdc.S[server_index].current_remaining_workload = vdc.S[server_index].previous_remaining_workload + vdc.AI[1].remaining_workload # 현재 remaining_workload에 arriving workload 추가

    for j in 1:length(vdc.S)   # 모든 서버에 대해
      for i in 1:length(vdc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        vdc.S[j].WIP[i].remaining_workload -= (vdc.S[j].current_speed/length(vdc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        vdc.S[j].current_remaining_workload -= (vdc.S[j].current_speed/length(vdc.S[j].WIP))*inter_event_time  # 서버 j의 workload 총합을 줄여준다.
      end
      # 스피드 업데이트
      vdc.S[j].previous_speed = vdc.S[j].current_speed
      vdc.S[j].current_speed = vdc.S[j].previous_speed + (1/server_power_2nd_diff(j, vdc.SS, vdc.S))*(x_dot(j, vdc.SS, vdc.S))
      # price 업데이트
      vdc.S[j].previous_price = vdc.S[j].current_price
      vdc.S[j].current_price = vdc.S[j].previous_price + p_dot(j, vdc.S)
    end

    # Updating next completion time   (모든 서버들에 대해서 )
    push!(vdc.S[server_index].WIP, vdc.AI[1]) # 그 서버에 일감 추가
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(vdc.S)
      for i in 1:length(vdc.S[j].WIP)
        if shortest_remaining_time > (vdc.S[j].WIP[i].remaining_workload/(vdc.S[j].current_speed/length(vdc.S[j].WIP)))
          shortest_remaining_time = (vdc.S[j].WIP[i].remaining_workload/(vdc.S[j].current_speed/length(vdc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          vdc.next_completion = vdc.current_time + shortest_remaining_time
          vdc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    vdc.S[server_index].num_in_server += 1 # 서버안에 있는 일감의 수 ++
    shift!(vdc.AI) # AI에서는 일감하나 뺌
    vdc.next_arrival = vdc.AI[1].arrival_time
  else#if vdc.next_completion == min(vdc.next_regular_update, vdc.next_arrival, vdc.next_completion)
    server_index = vdc.next_completion_info["server_num"]
    WIP_index = vdc.next_completion_info["WIP_num"]
    inter_event_time = vdc.next_completion - vdc.current_time
    vdc.current_time = vdc.next_completion
    println(f,"(Time: $(vdc.current_time)) Current event: Completion ($(vdc.passed_arrivals+1)th, server: $server_index , server $server_index's remaining WIPs: $(length(vdc.S[server_index].WIP))")

    # for summarizing
    if vdc.warmed_up == true
      if vdc.current_time - vdc.S[server_index].WIP[WIP_index].arrival_time > vdc.SS[server_index].δ
        push!(sojourn_time_array[server_index], 1)
      else
        push!(sojourn_time_array[server_index], 0)
      end
    end

    vdc.S[server_index].previous_remaining_workload = vdc.S[server_index].current_remaining_workload  # 기존 remaining_workload 저장

    for j in 1:length(vdc.S)   # 모든 서버에 대해
      for i in 1:length(vdc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        vdc.S[j].WIP[i].remaining_workload -= (vdc.S[j].current_speed/length(vdc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        vdc.S[j].current_remaining_workload -= (vdc.S[j].current_speed/length(vdc.S[j].WIP))*inter_event_time  # 서버 j의 workload 총합을 줄여준다.
      end
      # 스피드 업데이트
      vdc.S[j].previous_speed = vdc.S[j].current_speed
      vdc.S[j].current_speed = vdc.S[j].previous_speed + (1/server_power_2nd_diff(j, vdc.SS, vdc.S))*x_dot(j, vdc.SS, vdc.S)
      # price 업데이트
      vdc.S[j].previous_price = vdc.S[j].current_price
      vdc.S[j].current_price = vdc.S[j].previous_price + p_dot(j, vdc.S)
    end

    # Updating next completion time   (모든 서버들에 대해서 )
    deleteat!(vdc.S[server_index].WIP, WIP_index)
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(vdc.S)
      for i in 1:length(vdc.S[j].WIP)
        if shortest_remaining_time > (vdc.S[j].WIP[i].remaining_workload/(vdc.S[j].current_speed/length(vdc.S[j].WIP)))
          shortest_remaining_time = (vdc.S[j].WIP[i].remaining_workload/(vdc.S[j].current_speed/length(vdc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          vdc.next_completion = vdc.current_time + shortest_remaining_time
          vdc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    if server_index_2 == 0 && WIP_index == 0 # 만약 데이터센터 안에 아무 arrival이 없다면
      vdc.next_completion = typemax(Float64)
    else
      vdc.S[server_index].num_in_server -= 1 # 서버안에 있는 일감의 수 --
    end
    vdc.passed_arrivals += 1
  end
end

function warm_up(vdc::VirtualDataCenter)
  println(f, "Warming up for $(vdc.warm_up_arrivals) arrivals.")
  iter = 1
  while vdc.passed_arrivals < vdc.warm_up_arrivals
    next_event(vdc)
    iter += 1
  end
  vdc.warmed_up = true
  println(f, "Warmed up.")
end

function run_to_end(vdc::VirtualDataCenter)
  # For plotting
  for j = 1:length(vdc.S)
    push!(speed_array, Float64[])
    push!(price_array, Float64[])
    push!(sojourn_time_array, Float64[])
  end

  if !vdc.warmed_up
      warm_up(vdc)
  end

  iter = 1
  while vdc.passed_arrivals < vdc.max_arrivals
    next_event(vdc)
    iter += 1
  end
  println(f, "Simulation finished")
end

# NHPP genereators (later it will be modified...)
function generate_NHPP1(f::Function, N::Int64)
    m = Model(solver = IpoptSolver(print_level = 0))
    @variable(m, a)
    @NLobjective(m, Max, 4.0-3*sin((π/12)*a))
    solve(m)
    λ = getobjectivevalue(m)

    x = Float64[]
    t = 0.0
    n = 0
    while n < N
      t -= (1/λ)*log(rand())
      if rand() <= f(t)/λ
        push!(x, t)
        n += 1
      end
    end
    return x
end

function generate_NHPP2(f::Function, N::Int64)
    m = Model(solver = IpoptSolver(print_level = 0))
    @variable(m, a)
    @NLobjective(m, Max, 2.0-1.5*sin((π/12)*a))
    solve(m)
    λ = getobjectivevalue(m)

    x = Float64[]
    t = 0.0
    n = 0
    while n < N
      t -= (1/λ)*log(rand())
      if rand() <= f(t)/λ
        push!(x, t)
        n += 1
      end
    end
    return x
end

function generate_NHPP3(f::Function, N::Int64)
    m = Model(solver = IpoptSolver(print_level = 0))
    @variable(m, a)
    @NLobjective(m, Max, 4.0-2.5*sin((π/12)*a))
    solve(m)
    λ = getobjectivevalue(m)

    x = Float64[]
    t = 0.0
    n = 0
    while n < N
      t -= (1/λ)*log(rand())
      if rand() <= f(t)/λ
        push!(x, t)
        n += 1
      end
    end
    return x
end

function generate_NHPP4(f::Function, N::Int64)
    m = Model(solver = IpoptSolver(print_level = 0))
    @variable(m, a)
    @NLobjective(m, Max, 10.0-5*sin((π/12)*a))
    solve(m)
    λ = getobjectivevalue(m)

    x = Float64[]
    t = 0.0
    n = 0
    while n < N
      t -= (1/λ)*log(rand())
      if rand() <= f(t)/λ
        push!(x, t)
        n += 1
      end
    end
    return x
end

function generate_NHPP5(f::Function, N::Int64)
    m = Model(solver = IpoptSolver(print_level = 0))
    @variable(m, a)
    @NLobjective(m, Max, 5.0-4*sin((π/12)*a))
    solve(m)
    λ = getobjectivevalue(m)

    x = Float64[]
    t = 0.0
    n = 0
    while n < N
      t -= (1/λ)*log(rand())
      if rand() <= f(t)/λ
        push!(x, t)
        n += 1
      end
    end
    return x
end

function workload_setter()
  WS = Workload_Setting[]
  push!(WS, Workload_Setting(20.0, "Exponential",0.25, t -> 4.0-3*sin((π/12)*t), 1.0, sqrt(0.25),"LogNormal",5.0,1.5,sqrt((5.0^2)*1.5)))
  push!(WS, Workload_Setting(20.0, "Exponential", 0.5, t -> 2.0-1.5*sin((π/12)*t), 1.0, sqrt(0.5), "LogNormal", 10.0, 2.0, sqrt((10.0^2)*2.0)))
  push!(WS, Workload_Setting(20.0, "Exponential", 0.25, t -> 4.0-2.5*sin((π/12)*t), 1.0, sqrt(0.25), "LogNormal", 5.0, 1.0, sqrt((5.0^2)*1.0)))
  push!(WS, Workload_Setting(20.0, "Exponential", 0.1, t -> 10.0-5*sin((π/12)*t), 1.0, sqrt(0.1), "LogNormal", 2.0, 0.8, sqrt((2.0^2)*0.8)))
  push!(WS, Workload_Setting(15.0, "Exponential", 0.2, t -> 5.0-4*sin((π/12)*t), 1.0, sqrt(0.2),"LogNormal", 3.0,0.5,sqrt((3.0^2)*0.5)))
  return WS
end

# app 별로 arrival시간, 일감 생성해서 Arrival_Information array를 리턴하는 함수
function arrival_generator()
  vector_1 = generate_NHPP1(WS[1].rate_inter_arrival, MAX_ARRIVALS*2)
  vector_2 = generate_NHPP1(WS[2].rate_inter_arrival, MAX_ARRIVALS*2)
  vector_3 = generate_NHPP1(WS[3].rate_inter_arrival, MAX_ARRIVALS*2)
  vector_4 = generate_NHPP1(WS[4].rate_inter_arrival, MAX_ARRIVALS*2)
  vector_5 = generate_NHPP1(WS[5].rate_inter_arrival, MAX_ARRIVALS*2)

  AI = Arrival_Information[]
  i = 1
  while i < MAX_ARRIVALS*5+1
    m = min(vector_1[1], vector_2[1], vector_3[1], vector_4[1], vector_5[1])
    if m == vector_1[1]
      push!(AI, Arrival_Information(i,1,m,rand(LogNormal(log(5.0),sqrt(log(1+1.5)))),typemax(Float64)))
      shift!(vector_1)
    elseif m == vector_2[1]
      push!(AI, Arrival_Information(i,2,m,rand(LogNormal(log(10.0),sqrt(log(1+2)))),typemax(Float64)))
      shift!(vector_2)
    elseif m == vector_3[1]
      push!(AI, Arrival_Information(i,3,m,rand(LogNormal(log(5.0),sqrt(log(1+1)))),typemax(Float64)))
      shift!(vector_3)
    elseif m == vector_4[1]
      push!(AI, Arrival_Information(i,4,m,rand(LogNormal(log(2.0),sqrt(log(0.8+1)))),typemax(Float64)))
      shift!(vector_4)
    else
      push!(AI, Arrival_Information(i,5,m,rand(LogNormal(log(3.0),sqrt(log(0.5+1)))),typemax(Float64)))
      shift!(vector_5)
    end
    i += 1
  end
  return AI
end

# 서버별 정보를 생성해서 Server_Setting array를 리턴하는 함수
function server_setter()
  SS = Server_Setting[]
  push!(SS, Server_Setting(5.0, 2*100.0, 150.0, 0.3333, 3, 3.0, 0.001, 100.0, 1000.0, (1,)))
  push!(SS, Server_Setting(7.0, 2*102.0, 250.0, 0.2, 3, 3.0, 0.001, 102.0, 2000.0, (1,)))
  push!(SS, Server_Setting(6.0, 2*99.0, 220.0, 1.0, 3, 3.0, 0.001, 99.0, 3000.0, (1,2)))
  push!(SS, Server_Setting(5.0, 2*105.0, 150.0, 0.6667, 3, 3.0, 0.001, 105.0, 1000.0, (1,2,3)))
  push!(SS, Server_Setting(7.0, 2*100.0, 300.0, 0.8, 3, 3.0, 0.001, 100.0, 2000.0, (2,3)))
  push!(SS, Server_Setting(8.0, 2*102.0, 350.0, 0.4, 3, 3.0, 0.001, 102.0, 3000.0, (2,3)))
  push!(SS, Server_Setting(6.0, 2*100.0, 220.0, 0.4286, 3, 3.0, 0.001, 100.0, 1000.0, (3,)))
  push!(SS, Server_Setting(7.0, 2*105.0, 350.0, 0.5, 3, 3.0, 0.001, 105.0, 2000.0, (4,5)))
  push!(SS, Server_Setting(8.0, 2*102.0, 400.0, 0.6, 3, 3.0, 0.001, 102.0, 3000.0, (4,5)))
  push!(SS, Server_Setting(10.0, 2*105.0, 700.0, 0.4444, 3, 3.0, 0.001, 105.0, 1000.0, (5,)))
  return SS
end

# 서버 객체를 만들어서 Server array를 리턴하는 함수
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
    # without κ
    # S[j].κ = 0.0
  end
  return S
end
