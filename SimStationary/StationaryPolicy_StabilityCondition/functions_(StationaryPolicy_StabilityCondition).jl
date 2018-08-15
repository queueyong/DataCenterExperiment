include("../../functions_distribution.jl")
include("./types_(StationaryPolicy_StabilityCondition).jl")
using StatsBase

function do_simulation(REPLICATION::Int64)
    SS = readServerSettingsData("../../server_settings.csv")
    WS = readWorkloadSettingsData("../../workload_settings.csv")
    S = constructServers(SS,WS)
    x, y = solveCentralized(SS, WS, S)
    file_record = open("./result/record_violation_prob_MCSimulation.txt" , "w")
    for i in 1:REPLICATION
        println("Replication $i")
        J = generateStationaryJobs(WS, RUNNING_TIME)
        S = constructServers(SS,WS)
        dc = DataCenter(SS, WS, J, S, REGULAR_UPDATE_INTERVAL, WARM_UP_ARRIVALS, MAX_ARRIVALS, WARM_UP_TIME, RUNNING_TIME)
        MSD = MCSim_Summary_Data(length(S))
        setOptimalPolicy(dc, x, y)
        run_replication_MCSim(dc, MSD, RUNNING_TIME, WARM_UP_TIME)
        writeRecord(file_record, MSD)
    end
    close(file_record)
    file_sum = open("./result/sum_MCSimlation.txt" , "w")
    writeViolationProb_MCSim(file_sum, file_record)
    close(file_sum)
end

function writeRecord(file_record::IOStream, MSD::MCSim_Summary_Data, dc::DataCenter)
    numServers = length(dc.S)
    violation_prob_array = [sum(MSD.sojourn_time_violation_array[j])/length(MSD.sojourn_time_violation_array[j]) for j in 1:numServers]
    temp_array = insert!(violation_prob_array, 1, dc.total_cumulative_power_consumption)
    writedlm(file_record, transpose(temp_array))
end

function saveRecord(record_array::Any, MSD::MCSim_Summary_Data, dc::DataCenter)
    numServers = length(dc.S)
    violation_prob_array = [sum(MSD.sojourn_time_violation_array[j])/length(MSD.sojourn_time_violation_array[j]) for j in 1:numServers]
    temp_array = insert!(violation_prob_array, 1, dc.total_cumulative_power_consumption)
    push!(record_array, temp_array)
end

function writeViolationProb_MCSim(file_sum::IOStream, file_record::IOStream)
    file_array = readdlm("./result/record_violation_prob_MCSimulation.txt")
    x , y = size(file_array)
    nReplications = x
    nServers = y-1
    average_power_consumption = sum(file_array[:,1])/nReplications
    average_violation_prob = [sum(file_array[:,j])/nReplications for j in 2:nServers+1]

    # Write summarization
    println(file_sum, "Total Cumulative Power Consumption: $average_power_consumption")
    println(file_sum, " ")
    println(file_sum, "Average violation probabilities:")
    for j = 1:nServers
      println(file_sum, "P[W_$j>=δ_$j]: $(average_violation_prob[j])")
    end
end

function writeViolationProb_MCSim(file_sum::IOStream, record_array::Any)
    nReplications = length(record_array)
    nServers = length(record_array[1]) - 1
    average_power_consumption = sum(record_array[i][1] for i in 1:nReplications)/nReplications
    average_violation_prob = [sum(record_array[1:end][j])/nReplications for j in 2:nServers+1]

    # Write summarization
    println(file_sum, "Total Cumulative Power Consumption: $average_power_consumption")
    println(file_sum, " ")
    println(file_sum, "Average violation probabilities:")
    for j = 1:nServers
      println(file_sum, "P[W_$j>=δ_$j]: $(average_violation_prob[j])")
    end
end

function convertSubStringToIntArray(str::SubString{String})::Array{Int}
    arr = Int[]
    for l in str
        if l != ','
            push!(arr, parse(Int,l))
        end
    end
    return arr
end

function readServerSettingsData(FILEPATH::String)::Array{Server_Setting}
    fa = readdlm(FILEPATH, ':')
    SS = Server_Setting[]
    for i in 1:size(fa)[1]-1
        j = i + 1
        push!(SS, Server_Setting(fa[j,2], fa[j,3], fa[j,4], fa[j,5],
                                fa[j,6], fa[j,7], fa[j,8], fa[j,9],
                                fa[j,10],convertSubStringToIntArray(fa[j,11])))
    end
    return SS
end

function readWorkloadSettingsData(FILEPATH::String)::Array{Workload_Setting}
    fa = readdlm(FILEPATH, ':')
    WS = Workload_Setting[]
    for i in 1:size(fa)[1]-1
        j = i + 1
        push!(WS, Workload_Setting(convert(String,fa[j,2]),
                                   fa[j,3], fa[j,4],
                                   convert(String,fa[j,5]),
                                   fa[j,6], fa[j,7]))
    end
    return WS
end

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

function constructServers(SS::Array{Server_Setting}, WS::Array{Workload_Setting})::Array{Server}
    S = Server[]
    for j in 1:length(SS)
        push!(S, Server(SS[j].x0, SS[j].x0, SS[j].p0, SS[j].p0))
        S[j].κ = 0.0
        #S[j].κ = kappa(j, SS, WS)
    end

    return S
end

function setOptimalPolicy(dc::DataCenter)
    # solve optimization problem
    speed_sol, routing_sol = solveCentralized(dc.SS,dc.WS,dc.S)

    # set optimal speed for servers
    for j in 1:length(speed_sol)
        dc.S[j].current_speed = speed_sol[j]
        dc.S[j].previous_speed = speed_sol[j]
        dc.S[j].optimal_speed = speed_sol[j]
    end

    # find unnecessary server (routing probability 0)
    for j in 1:length(dc.S)
        prob_sum = 0.0
        for i in 1:length(dc.WS)
            prob_sum += routing_sol[i][j]
        end
        if prob_sum == 0.0
            dc.S[j].current_speed = 0.0
            dc.S[j].previous_speed = 0.0
            dc.S[j].optimal_speed = 0.0
            dc.S[j].κ = 0.0
        end
    end

    app_containing_server_list = Dict()
    for i in 1:length(dc.WS)
        app_containing_server_list[i] = Int64[]
    end

    for i in 1:length(dc.WS)
        for j in 1:length(dc.SS)
            if in(i, dc.SS[j].Apps)
                push!(app_containing_server_list[i], j)
            end
        end
    end

    routing_prob = [Float64[] for i in 1:length(dc.WS)]
    for i in 1:length(dc.WS)
        for j in app_containing_server_list[i]
            push!(routing_prob[i], routing_sol[i][j]/((1/WS[i].mean_inter_arrival)*WS[i].mean_jobsize))
        end
    end


    dc.app_containing_server_list = app_containing_server_list
    dc.routing_probability = routing_prob

    return (speed_sol, routing_sol)
end

function setOptimalPolicy(dc::DataCenter, speed_sol::Any, routing_sol::Any)
    # set optimal speed for servers
    for j in 1:length(speed_sol)
        dc.S[j].current_speed = speed_sol[j]
        dc.S[j].previous_speed = speed_sol[j]
        dc.S[j].optimal_speed = speed_sol[j]
    end

    # find unnecessary server and turn off (routing probability 0)
    for j in 1:length(dc.S)
        prob_sum = 0.0
        for i in 1:length(dc.WS)
            prob_sum += routing_sol[i][j]
        end
        if prob_sum == 0.0
            dc.S[j].current_speed = 0.0
            dc.S[j].previous_speed = 0.0
            dc.S[j].optimal_speed = 0.0
            dc.S[j].κ = 0.0
        end
    end

    app_containing_server_list = Dict()
    for i in 1:length(dc.WS)
        app_containing_server_list[i] = Int64[]
    end

    for i in 1:length(dc.WS)
        for j in 1:length(dc.SS)
            if in(i, dc.SS[j].Apps)
                push!(app_containing_server_list[i], j)
            end
        end
    end

    routing_prob = [Float64[] for i in 1:length(dc.WS)]
    for i in 1:length(dc.WS)
        for j in app_containing_server_list[i]
            push!(routing_prob[i], routing_sol[i][j]/((1/WS[i].mean_inter_arrival)*WS[i].mean_jobsize))
        end
    end

    dc.app_containing_server_list = app_containing_server_list
    dc.routing_probability = routing_prob
end


function server_power(j::Int64, SS::Array{Server_Setting}, S::Array{Server})
  return SS[j].K + (SS[j].α)*(S[j].current_speed^SS[j].n)
end

function sampleWhereToRoute(dc::DataCenter, i::Int64)
    return sample(dc.app_containing_server_list[i], Weights(dc.routing_probability[i]))
end

function updateServerSpeed!(dc::DataCenter)
    for j in 1:length(dc.S)
        t = dc.current_time
        μ_max = 0.0
        num_jobs = length(dc.S[j].WIP)
        for i in 1:num_jobs
            if μ_max < dc.S[j].WIP[i].remaining_jobsize * num_jobs / (dc.SS[j].δ - (t - dc.S[j].WIP[i].arrival_time))
                μ_max = dc.S[j].WIP[i].remaining_jobsize * num_jobs / (dc.SS[j].δ - (t - dc.S[j].WIP[i].arrival_time))
            end
        end

        if μ_max <= dc.SS[j].γ
            dc.S[j].current_speed = dc.SS[j].γ
        elseif μ_max >= dc.SS[j].Γ
            dc.S[j].current_speed = dc.SS[j].Γ
        else
            dc.S[j].current_speed = μ_max
        end
    end
end

function next_event(dc::DataCenter, PD::Plot_Data)
  if dc.next_regular_update == min(dc.next_regular_update, dc.next_arrival, dc.next_completion)
    push!(PD.time_array, dc.current_time) # 시간 기록
    push!(PD.total_cumulative_power_consumption_array, dc.total_cumulative_power_consumption) # 누적 전력소모량 총합 기록
    inter_event_time = dc.next_regular_update - dc.current_time   # 지난이벤트와 지금이벤트의 시간간격을 저장
    dc.current_time = dc.next_regular_update                      # 시뮬레이터의 현재 시간을 바꿈
    # remaining_jobsize 업데이트
    for j in 1:length(dc.S)   # 모든 서버에 대해
      for i in 1:length(dc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        dc.S[j].WIP[i].remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 각 arrival의 jobsize 를 줄여준다
        dc.S[j].current_remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 서버 j의 jobsize 총합을 줄여준다.
      end

      # For plotting speed, price, and κ
      push!(PD.speed_array[j], dc.S[j].current_speed)
      push!(PD.price_array[j], dc.S[j].current_price)
      push!(PD.buffer_array[j], dc.S[j].κ)
      push!(PD.cumulative_power_consumption_array[j], dc.S[j].cumulative_power_consumption)
      push!(PD.num_in_server_array[j], dc.S[j].num_in_server)

      # 서버 j 누적 전력 소모량 업데이트
      consumption = inter_event_time*server_power(j,dc.SS, dc.S)
      dc.S[j].cumulative_power_consumption += consumption
      dc.total_cumulative_power_consumption += consumption
#=
      # 스피드 업데이트
      dc.S[j].previous_speed = dc.S[j].current_speed
      dc.S[j].current_speed = (dc.S[j].previous_speed) + ((1/server_power_2nd_diff(j, dc.SS, dc.S))*(x_dot(j, dc.SS, dc.S)))
      #dc.S[j].current_speed = dc.S[j].κ + dc.S[j].current_remaining_jobsize

      # price 업데이트
      dc.S[j].previous_price = dc.S[j].current_price
      dc.S[j].current_price = dc.S[j].previous_price + p_dot(j, dc.S)
=#
    end

    # completion_time을 계산해야함  (모든 서버들에 대해서 )
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(dc.S)
      for i in 1:length(dc.S[j].WIP)
        if shortest_remaining_time > (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          shortest_remaining_time = (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          dc.next_completion = dc.current_time + shortest_remaining_time
          dc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    if server_index_2 == 0 && WIP_index == 0 # 만약 데이터센터 안에 아무 arrival이 없다면
      dc.next_completion = typemax(Float64)
      dc.next_regular_update += dc.regular_update_interval
    else
      dc.next_regular_update += dc.regular_update_interval
    end

  elseif dc.next_arrival == min(dc.next_regular_update, dc.next_arrival, dc.next_completion)
    inter_event_time = dc.next_arrival - dc.current_time   # 지난이벤트와 지금이벤트의 시간간격을 저장
    dc.current_time = dc.next_arrival                      # 시뮬레이터의 현재 시간을 바꿈

    # Routing job and Workload increment
    server_index = sampleWhereToRoute(dc, dc.J[1].app_type)
    #server_index = find_min_price_server(dc.J[1].app_type, dc.SS, dc.S)    # 일감의 type과 현재 서버들의 price를 기반으로  routing할 서버를 결정

    println(PD.file_record,"(Time: $(dc.current_time)) Current event: New arrival ($(dc.J[1].index)th arrival, app_type: $(dc.J[1].app_type), jobsize: $(dc.J[1].remaining_jobsize), server_dispatched: $server_index)")

    dc.S[server_index].previous_remaining_jobsize = dc.S[server_index].current_remaining_jobsize  # 기존 remaining_jobsize 저장
    dc.S[server_index].current_remaining_jobsize = dc.S[server_index].previous_remaining_jobsize + dc.J[1].remaining_jobsize # 현재 remaining_jobsize에 arriving jobsize 추가

    # Reducing jobsize
    for j in 1:length(dc.S)   # 모든 서버에 대해
      for i in 1:length(dc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        dc.S[j].WIP[i].remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        dc.S[j].current_remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 서버 j의 jobsize 총합을 줄여준다.
      end
      # 서버 j 누적 전력 소모량 업데이트
      consumption = inter_event_time*server_power(j,dc.SS, dc.S)
      dc.S[j].cumulative_power_consumption += consumption
      dc.total_cumulative_power_consumption += consumption
#=
      # 스피드 업데이트
      dc.S[j].previous_speed = dc.S[j].current_speed
      dc.S[j].current_speed = dc.S[j].previous_speed + (1/server_power_2nd_diff(j, dc.SS, dc.S))*(x_dot(j, dc.SS, dc.S))
#      dc.S[j].current_speed = dc.S[j].κ + dc.S[j].current_remaining_jobsize

      # price 업데이트
      dc.S[j].previous_price = dc.S[j].current_price
      dc.S[j].current_price = dc.S[j].previous_price + p_dot(j, dc.S)
=#
    end

    # Routing 된 서버의 WIP에 job object 추가
    push!(dc.S[server_index].WIP, dc.J[1])

    # optimal policy: set server speed by optimal speed
    dc.S[server_index].current_speed = dc.S[server_index].optimal_speed

    # Updating next completion time
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(dc.S)
      for i in 1:length(dc.S[j].WIP)
        if shortest_remaining_time > (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          shortest_remaining_time = (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          dc.next_completion = dc.current_time + shortest_remaining_time
          dc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    dc.S[server_index].num_in_server += 1 # 서버안에 있는 일감의 수 ++
    shift!(dc.J) # J에서는 일감하나 뺌
    dc.next_arrival = dc.J[1].arrival_time
  elseif dc.next_completion == min(dc.next_regular_update, dc.next_arrival, dc.next_completion)
    server_index = dc.next_completion_info["server_num"]
    WIP_index = dc.next_completion_info["WIP_num"]
    inter_event_time = dc.next_completion - dc.current_time
    dc.current_time = dc.next_completion
    println(PD.file_record,"(Time: $(dc.current_time)) Current event: Completion ($(dc.passed_arrivals+1)th, server: $server_index , server $server_index's remaining WIPs: $(length(dc.S[server_index].WIP))")

    # Count QoS constraint violation
    if dc.warmed_up == true
      sojourn_time = dc.current_time - dc.S[server_index].WIP[WIP_index].arrival_time
      if sojourn_time > dc.SS[server_index].δ
        push!(PD.sojourn_time_violation_array[server_index], 1)
      else
        push!(PD.sojourn_time_violation_array[server_index], 0)
      end

      push!(PD.sojourn_time_array[server_index], sojourn_time)
    end

    dc.S[server_index].previous_remaining_jobsize = dc.S[server_index].current_remaining_jobsize  # 기존 remaining_jobsize 저장

    for j in 1:length(dc.S)   # 모든 서버에 대해
      for i in 1:length(dc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        dc.S[j].WIP[i].remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        dc.S[j].current_remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 서버 j의 jobsize 총합을 줄여준다.
      end
      # 서버 j 누적 전력 소모량 업데이트
      consumption = inter_event_time*server_power(j,dc.SS, dc.S)
      dc.S[j].cumulative_power_consumption += consumption
      dc.total_cumulative_power_consumption += consumption
#=
      # 스피드 업데이트
      dc.S[j].previous_speed = dc.S[j].current_speed
      dc.S[j].current_speed = dc.S[j].previous_speed + (1/server_power_2nd_diff(j, dc.SS, dc.S))*x_dot(j, dc.SS, dc.S)
      #dc.S[j].current_speed = dc.S[j].κ + dc.S[j].current_remaining_jobsize
      # price 업데이트
      dc.S[j].previous_price = dc.S[j].current_price
      dc.S[j].current_price = dc.S[j].previous_price + p_dot(j, dc.S)
=#
    end

    # remove the completed job
    deleteat!(dc.S[server_index].WIP, WIP_index)
    dc.S[server_index].num_in_server -= 1 # 그 서버안에 있는 일감의 수 -1


    # optimal policy: if no job presents, set speed by γ
    if dc.S[server_index].num_in_server == 0
        dc.S[server_index].current_speed = dc.SS[server_index].γ
    end

    # Updating next completion time
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(dc.S)
      for i in 1:length(dc.S[j].WIP)
        if shortest_remaining_time > (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          shortest_remaining_time = (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          dc.next_completion = dc.current_time + shortest_remaining_time
          dc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    if server_index_2 == 0 && WIP_index == 0 # 만약 전체 데이터센터 안에 아무 arrival이 없다면
      dc.next_completion = typemax(Float64)
    end
    dc.passed_arrivals += 1
  end
end

function warm_up(dc::DataCenter, PD::Plot_Data, WARM_UP_TIME::Float64)
  println(PD.file_record, "Warming up for $(WARM_UP_TIME) times.")
  while dc.current_time < WARM_UP_TIME
    next_event(dc, PD)
  end
  dc.warmed_up = true
  println(PD.file_record, "Warmed up.")
end

function run_to_end(dc::DataCenter, PD::Plot_Data, REPLICATION_TIME::Float64, WARM_UP_TIME::Float64)
    # warming up
    warm_up(dc, PD, WARM_UP_TIME)

    while dc.current_time < REPLICATION_TIME
        next_event(dc, PD)
    end
    println(PD.file_record, "Simulation finished.")
end

function run_replication_MCSim(dc::DataCenter, MSD::MCSim_Summary_Data, REPLICATION_TIME::Float64, WARM_UP_TIME::Float64)
    # warming up
    warm_up_MCSim(dc, MSD, WARM_UP_TIME)

    while dc.current_time < REPLICATION_TIME
        next_event_MCSim(dc, MSD)
    end
    println("Replication done.")
end

function warm_up_MCSim(dc::DataCenter, MSD::MCSim_Summary_Data, WARM_UP_TIME::Float64)
  #println("Warming up for $(WARM_UP_TIME) times...")
  while dc.current_time < WARM_UP_TIME
    next_event_MCSim(dc, MSD)
  end
  dc.warmed_up = true
  #println("Warmed up.")
end

function next_event_MCSim(dc::DataCenter, MSD::MCSim_Summary_Data)
  if dc.next_regular_update == min(dc.next_regular_update, dc.next_arrival, dc.next_completion)
#    push!(PD.time_array, dc.current_time) # 시간 기록
#    push!(PD.total_cumulative_power_consumption_array, dc.total_cumulative_power_consumption) # 누적 전력소모량 총합 기록
    inter_event_time = dc.next_regular_update - dc.current_time   # 지난이벤트와 지금이벤트의 시간간격을 저장
    dc.current_time = dc.next_regular_update                      # 시뮬레이터의 현재 시간을 바꿈
    # remaining_jobsize 업데이트
    for j in 1:length(dc.S)   # 모든 서버에 대해
      for i in 1:length(dc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        dc.S[j].WIP[i].remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 각 arrival의 jobsize 를 줄여준다
        dc.S[j].current_remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 서버 j의 jobsize 총합을 줄여준다.
      end

      # For plotting speed, price, and κ
#      push!(PD.speed_array[j], dc.S[j].current_speed)
#      push!(PD.price_array[j], dc.S[j].current_price)
#      push!(PD.buffer_array[j], dc.S[j].κ)
#      push!(PD.cumulative_power_consumption_array[j], dc.S[j].cumulative_power_consumption)
#      push!(PD.num_in_server_array[j], dc.S[j].num_in_server)

      # 서버 j 누적 전력 소모량 업데이트
      consumption = inter_event_time*server_power(j,dc.SS, dc.S)
      dc.S[j].cumulative_power_consumption += consumption
      dc.total_cumulative_power_consumption += consumption
#=
      # 스피드 업데이트
      dc.S[j].previous_speed = dc.S[j].current_speed
      dc.S[j].current_speed = (dc.S[j].previous_speed) + ((1/server_power_2nd_diff(j, dc.SS, dc.S))*(x_dot(j, dc.SS, dc.S)))
      #dc.S[j].current_speed = dc.S[j].κ + dc.S[j].current_remaining_jobsize

      # price 업데이트
      dc.S[j].previous_price = dc.S[j].current_price
      dc.S[j].current_price = dc.S[j].previous_price + p_dot(j, dc.S)
=#
    end

    # completion_time을 계산해야함  (모든 서버들에 대해서 )
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(dc.S)
      for i in 1:length(dc.S[j].WIP)
        if shortest_remaining_time > (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          shortest_remaining_time = (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          dc.next_completion = dc.current_time + shortest_remaining_time
          dc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    if server_index_2 == 0 && WIP_index == 0 # 만약 데이터센터 안에 아무 arrival이 없다면
      dc.next_completion = typemax(Float64)
      dc.next_regular_update += dc.regular_update_interval
    else
      dc.next_regular_update += dc.regular_update_interval
    end

  elseif dc.next_arrival == min(dc.next_regular_update, dc.next_arrival, dc.next_completion)
    inter_event_time = dc.next_arrival - dc.current_time   # 지난이벤트와 지금이벤트의 시간간격을 저장
    dc.current_time = dc.next_arrival                      # 시뮬레이터의 현재 시간을 바꿈

    # Routing job and Workload increment
    server_index = sampleWhereToRoute(dc, dc.J[1].app_type)
    #server_index = find_min_price_server(dc.J[1].app_type, dc.SS, dc.S)    # 일감의 type과 현재 서버들의 price를 기반으로  routing할 서버를 결정

#    println(PD.file_record,"(Time: $(dc.current_time)) Current event: New arrival ($(dc.J[1].index)th arrival, app_type: $(dc.J[1].app_type), jobsize: $(dc.J[1].remaining_jobsize), server_dispatched: $server_index)")

    dc.S[server_index].previous_remaining_jobsize = dc.S[server_index].current_remaining_jobsize  # 기존 remaining_jobsize 저장
    dc.S[server_index].current_remaining_jobsize = dc.S[server_index].previous_remaining_jobsize + dc.J[1].remaining_jobsize # 현재 remaining_jobsize에 arriving jobsize 추가

    # Reducing jobsize
    for j in 1:length(dc.S)   # 모든 서버에 대해
      for i in 1:length(dc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        dc.S[j].WIP[i].remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        dc.S[j].current_remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 서버 j의 jobsize 총합을 줄여준다.
      end
      # 서버 j 누적 전력 소모량 업데이트
      consumption = inter_event_time*server_power(j,dc.SS, dc.S)
      dc.S[j].cumulative_power_consumption += consumption
      dc.total_cumulative_power_consumption += consumption
#=
      # 스피드 업데이트
      dc.S[j].previous_speed = dc.S[j].current_speed
      dc.S[j].current_speed = dc.S[j].previous_speed + (1/server_power_2nd_diff(j, dc.SS, dc.S))*(x_dot(j, dc.SS, dc.S))
#      dc.S[j].current_speed = dc.S[j].κ + dc.S[j].current_remaining_jobsize

      # price 업데이트
      dc.S[j].previous_price = dc.S[j].current_price
      dc.S[j].current_price = dc.S[j].previous_price + p_dot(j, dc.S)
=#
    end

    # optimal policy: set server speed by optimal speed
    dc.S[server_index].previous_speed = dc.S[server_index].current_speed
    dc.S[server_index].current_speed = dc.S[server_index].optimal_speed


    # Updating next completion time
    push!(dc.S[server_index].WIP, dc.J[1]) # Routing 된 서버의 WIP에 job object 추가
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(dc.S)
      for i in 1:length(dc.S[j].WIP)
        if shortest_remaining_time > (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          shortest_remaining_time = (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          dc.next_completion = dc.current_time + shortest_remaining_time
          dc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    dc.S[server_index].num_in_server += 1 # 서버안에 있는 일감의 수 ++
    shift!(dc.J) # J에서는 일감하나 뺌
    dc.next_arrival = dc.J[1].arrival_time
  elseif dc.next_completion == min(dc.next_regular_update, dc.next_arrival, dc.next_completion)
    server_index = dc.next_completion_info["server_num"]
    WIP_index = dc.next_completion_info["WIP_num"]
    inter_event_time = dc.next_completion - dc.current_time
    dc.current_time = dc.next_completion
#    println(PD.file_record,"(Time: $(dc.current_time)) Current event: Completion ($(dc.passed_arrivals+1)th, server: $server_index , server $server_index's remaining WIPs: $(length(dc.S[server_index].WIP))")

    # Count QoS constraint violation
    if dc.warmed_up == true
      sojourn_time = dc.current_time - dc.S[server_index].WIP[WIP_index].arrival_time
      if sojourn_time > dc.SS[server_index].δ
        push!(MSD.sojourn_time_violation_array[server_index], 1)
      else
        push!(MSD.sojourn_time_violation_array[server_index], 0)
      end

      push!(MSD.sojourn_time_array[server_index], sojourn_time)
    end

    dc.S[server_index].previous_remaining_jobsize = dc.S[server_index].current_remaining_jobsize  # 기존 remaining_jobsize 저장

    for j in 1:length(dc.S)   # 모든 서버에 대해
      for i in 1:length(dc.S[j].WIP)   # 각 서버 안에 있는 arrival에 대해
        dc.S[j].WIP[i].remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 각 arrival의 worklaod를 줄여준다
        dc.S[j].current_remaining_jobsize -= (dc.S[j].current_speed/length(dc.S[j].WIP))*inter_event_time  # 서버 j의 jobsize 총합을 줄여준다.
      end
      # 서버 j 누적 전력 소모량 업데이트
      consumption = inter_event_time*server_power(j,dc.SS, dc.S)
      dc.S[j].cumulative_power_consumption += consumption
      dc.total_cumulative_power_consumption += consumption

#=
      # 스피드 업데이트
      dc.S[j].previous_speed = dc.S[j].current_speed
      dc.S[j].current_speed = dc.S[j].previous_speed + (1/server_power_2nd_diff(j, dc.SS, dc.S))*x_dot(j, dc.SS, dc.S)
      #dc.S[j].current_speed = dc.S[j].κ + dc.S[j].current_remaining_jobsize
      # price 업데이트
      dc.S[j].previous_price = dc.S[j].current_price
      dc.S[j].current_price = dc.S[j].previous_price + p_dot(j, dc.S)
=#
    end

    # remove the completed job
    deleteat!(dc.S[server_index].WIP, WIP_index)
    dc.S[server_index].num_in_server -= 1 # 그 서버안에 있는 일감의 수 -1

    # optimal policy: if no job presents, set speed by κ
    if dc.S[server_index].num_in_server == 0
        dc.S[server_index].current_speed = 0.0
        #dc.S[server_index].current_speed = dc.S[server_index].κ
    end

    # Updating next completion time
    server_index_2 = 0
    WIP_index = 0
    shortest_remaining_time = typemax(Float64)

    for j in 1:length(dc.S)
      for i in 1:length(dc.S[j].WIP)
        if shortest_remaining_time > (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          shortest_remaining_time = (dc.S[j].WIP[i].remaining_jobsize/(dc.S[j].current_speed/length(dc.S[j].WIP)))
          WIP_index = i
          server_index_2 = j
          dc.next_completion = dc.current_time + shortest_remaining_time
          dc.next_completion_info = Dict("server_num"=>server_index_2, "WIP_num"=>WIP_index)
        end
      end
    end

    if server_index_2 == 0 && WIP_index == 0 # 만약 전체 데이터센터 안에 아무 arrival이 없다면
      dc.next_completion = typemax(Float64)
    end
    dc.passed_arrivals += 1
  end
end
