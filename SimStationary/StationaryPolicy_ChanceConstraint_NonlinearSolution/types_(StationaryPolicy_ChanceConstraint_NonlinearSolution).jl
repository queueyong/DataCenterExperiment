using Distributions

type Server_Setting
  γ::Any # server speed lower bound
  Γ::Any # server speed upper bound
  K::Any # power function parameter 1
  α::Any # power function parameter 2
  n::Int64 # power function parameter 3
  δ::Any # QoS constraint parameter 1
  ϵ::Any # QoS constraint parameter 2
  x0::Any # initial server speed
  p0::Any # initial server price
  Apps::Array{Int} # assigned application set
end

type Workload_Setting
  str_dist_inter_arrival::String
  mean_inter_arrival::Any
  scv_inter_arrival::Any
  str_dist_jobsize::String
  mean_jobsize::Any
  scv_jobsize::Any
  dist_inter_arrival::Distribution
  dist_jobsize::Distribution
  function Workload_Setting(dist_ia, mean_ia, scv_ia, dist_js, mean_js, scv_js)
    str_dist_inter_arrival = dist_ia
    mean_inter_arrival = mean_ia
    scv_inter_arrival = scv_ia
    str_dist_jobsize = dist_js
    mean_jobsize = mean_js
    scv_jobsize = scv_js
    dist_inter_arrival = Distribution_generator(dist_ia, mean_ia, scv_ia)[1]
    dist_jobsize = Distribution_generator(dist_js, mean_js, scv_js)[1]
    new(str_dist_inter_arrival,
        mean_inter_arrival,
        scv_inter_arrival,
        str_dist_jobsize,
        mean_jobsize,
        scv_jobsize,
        dist_inter_arrival,
        dist_jobsize)
  end
end

type Job
  index::Int64
  app_type::Int64
  arrival_time::Any
  remaining_jobsize::Any
  completion_time::Any
end

type Server
  previous_speed::Any
  current_speed::Any

  previous_price::Any
  current_price::Any

  previous_remaining_jobsize::Any
  current_remaining_jobsize::Any

  num_in_server::Int64
  indices_in_server::Array{Int}           # indices of jobs in the server
  κ::Any                                  # speed buffer of the server
  WIP::Array{Job}                         # Work In Process: it contains job objects
  cumulative_power_consumption::Any       # cumulative power consumption of the server
  optimal_speed                           # optimal_speed calculated by the optimization problem

  function Server(previous_speed::Any,
                  current_speed::Any,
                  previous_price::Any,
                  current_price::Any)
    previous_remaining_jobsize = 0.0
    current_remaining_jobsize = 0.0
    num_in_server = 0
    indices_in_server = Int[]
    κ = 0.0
    WIP = Job[]
    cumulative_power_consumption = 0.0
    optimal_speed = 0.0
    new(previous_speed,
        current_speed,
        previous_price,
        current_price,
        previous_remaining_jobsize,
        current_remaining_jobsize,
        num_in_server,
        indices_in_server,
        κ,
        WIP,
        cumulative_power_consumption,
        optimal_speed)
  end
end

type DataCenter
  ## These variables are set directly by the creator
  SS::Array{Server_Setting}                     # Server_Setting을 담는 배열
  WS::Array{Workload_Setting}                   # Workload_Setting을 담는 배열
  J::Array{Job}                                 # Job을 담는 배열
  S::Array{Server}                              # type Server 담는 배열
  regular_update_interval::Float64              # regular update interval
  warm_up_arrivals::Int64                       # 웜업 arrival의 수
  max_arrivals::Int64                           # 최대 arrival의 수
  warm_up_time::Float64                         # 웜업 시간
  running_time::Float64                     # 시뮬레이션 시간

  ## Internal variables - Set by constructor
  passed_arrivals::Int64              # 서비스받고 떠난 일감의 수
  current_time::Any               # 현재 시각
  inter_event_time::Any           # 지난이벤트와 현재 이벤트의 시간간격
  warmed_up::Bool                     # 웜업 됐는지 안됏는지
  next_arrival::Any               # 다음 도착 시각
  next_completion::Any            # 다음 완료 시각
  next_completion_info::Dict          # 다음 완료의 정보 (서버번호, Job 번호)
  next_regular_update::Any        # 다음 주기적 speed & price update 시각
  next_buffer_update::Any         # 다음 buffer update 시각
  buffer_update_counter::Int64        # 몇 번째 buffer update인지 count
  total_cumulative_power_consumption::Any   # 누적 전력 소모량 총합
  app_containing_server_list::Dict
  routing_probability::Array{Array{Float64}}

  # constructor definition
  function DataCenter(SS::Array{Server_Setting},
                      WS::Array{Workload_Setting},
                      J::Array{Job},
                      S::Array{Server},
                      regular_update_interval::Float64,
                      warm_up_arrivals::Int64,
                      max_arrivals::Int64,
                      warm_up_time::Float64,
                      running_time::Float64)
   passed_arrivals = 0       # 서비스받고 떠난 고객수
   current_time = 0.00       # 현재 시각
   inter_event_time = 0.00   # 지난 이벤트와 현재 이벤트와의 시간 간격
   warmed_up = false
   next_arrival = J[1].arrival_time
   next_completion = typemax(Float64)
   next_completion_info = Dict()
   next_regular_update = regular_update_interval
   next_buffer_update = 0.0
   buffer_update_counter = 0
   total_cumulative_power_consumption = 0.0
   app_containing_server_list = Dict()
   routing_probability = Array{Float64}[]
   new(SS, WS, J, S, regular_update_interval, warm_up_arrivals, max_arrivals, warm_up_time, running_time,
       passed_arrivals,
       current_time,
       inter_event_time,
       warmed_up,
       next_arrival,
       next_completion,
       next_completion_info,
       next_regular_update,
       next_buffer_update,
       buffer_update_counter,
       total_cumulative_power_consumption,
       app_containing_server_list,
       routing_probability)
  end
end

type MCSim_Summary_Data
  sojourn_time_violation_array::Array{Array{Int64}}
  sojourn_time_array::Array{Array{Float64}}
  function MCSim_Summary_Data(numServers::Int64)
    sojourn_time_violation_array = [Int64[] for i in 1:numServers]
    sojourn_time_array = [Float64[] for i in 1:numServers]
    new(sojourn_time_violation_array, sojourn_time_array)
  end
end

type Plot_Data
  time_array::Array{Float64}
  speed_array::Array{Array{Float64}}
  price_array::Array{Array{Float64}}
  sojourn_time_violation_array::Array{Array{Float64}}
  sojourn_time_array::Array{Array{Float64}}
  buffer_array::Array{Array{Float64}}
  cumulative_power_consumption_array::Array{Array{Float64}}
  total_cumulative_power_consumption_array::Array{Float64}
  num_in_server_array::Array{Array{Float64}}
  file_record::IOStream
  file_summarization::IOStream
  function Plot_Data(S::Array{Server}, _file_record::IOStream, _file_summarization::IOStream)
    time_array = Float64[]
    speed_array = Array{Float64}[]
    price_array = Array{Float64}[]
    sojourn_time_violation_array = Array{Float64}[]
    sojourn_time_array = Array{Float64}[]
    buffer_array = Array{Float64}[]
    cumulative_power_consumption_array = Array{Float64}[]
    total_cumulative_power_consumption_array = Float64[]
    num_in_server_array = Array{Float64}[]
    for j = 1:length(S)
      push!(speed_array, Float64[])
      push!(price_array, Float64[])
      push!(sojourn_time_violation_array, Float64[])
      push!(sojourn_time_array, Float64[])
      push!(buffer_array, Float64[])
      push!(cumulative_power_consumption_array, Float64[])
      push!(num_in_server_array, Float64[])
    end
    file_record = _file_record
    file_summarization = _file_summarization
    new(time_array, speed_array, price_array, sojourn_time_violation_array,sojourn_time_array, buffer_array,
        cumulative_power_consumption_array, total_cumulative_power_consumption_array, num_in_server_array,
        file_record, file_summarization)
  end
end
