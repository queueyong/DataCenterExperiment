type Server_Setting
  γ::Float64 # server speed lower bound
  Γ::Float64 # server speed upper bound
  K::Float64 # power function parameter 1
  α::Float64 # power function parameter 2
  n::Int64 # power function parameter 3
  δ::Float64 # QoS constraint parameter 1
  ϵ::Float64 # QoS constraint parameter 2
  x_0::Float64 # initial server speed
  p_0::Float64 # initial server price
  Apps::Tuple # assigned application set
end

type Workload_Setting
  instant_demand::Float64

  inter_arrival_distribution::Any
  mean_inter_arrival::Float64
  scv_inter_arrival::Float64

  workload_distribution::Any
  mean_workload::Float64
  scv_workload::Float64

  arrival_rate_function::Function
end

type Arrival_Information
  arrival_index::Int64        # 일감 번호
  app_type::Int64             # 앱 타입
  arrival_time::Float64       # 도착 시간
  remaining_workload::Float64 # 남은 일감의 양
  completion_time::Float64    # 작업 완료 시간
end

type Server
  previous_speed::Float64  # 기존 속도
  current_speed::Float64   # 현재 속도

  previous_price::Float64  # 기존 price
  current_price::Float64   # 현재 price

  previous_remaining_workload::Float64 # 기존 remaining workload 총합 (t 시점)
  current_remaining_workload::Float64  # 현재 remaining workload 총합 (t+1 시점)

  num_in_server::Int64                        # 서버안의 일감의 수
  indices_in_server::Tuple                    # 서버안의 일감들의 번호들?
  κ::Float64                                  # 서버의 버퍼 크기
  WIP::Array{Arrival_Information}             # 서버안에 있는 일감을 담는 배열
  cumulative_power_consumption::Float64       # 누적 전력 소모량

  function Server(previous_speed::Float64,
                  current_speed::Float64,
                  previous_price::Float64,
                  current_price::Float64)
    previous_remaining_workload = 0.0
    current_remaining_workload = 0.0
    num_in_server = 0
    indices_in_server = ()
    κ = 0.0
    WIP = Arrival_Information[]
    cumulative_power_consumption = 0.0
    new(previous_speed,
        current_speed,
        previous_price,
        current_price,
        previous_remaining_workload,
        current_remaining_workload,
        num_in_server,
        indices_in_server,
        κ,
        WIP,
        cumulative_power_consumption)
  end
end

type VirtualDataCenter
  ## These variables are set directly by the creator
  WS::Array{Workload_Setting}                   # Workload_Setting을 담는 배열
  AI::Array{Arrival_Information}                # Arrival_Information을 담는 배열
  SS::Array{Server_Setting}                     # Server_Setting을 담는 배열
  warm_up_arrivals::Int64                       # 웜업 arrival의 수
  max_arrivals::Int64                           # 최대 arrival의 수
  warm_up_time::Float64                         # 웜업 시간
  replication_time::Float64                     # 시뮬레이션 시간
  regular_update_interval::Float64              # regular update interval
  S::Array{Server}                              # type Server 담는 배열

  ## Internal variables - Set by constructor
  passed_arrivals::Int64              # 서비스받고 떠난 일감의 수
  current_time::Float64               # 현재 시각
  inter_event_time::Float64           # 지난이벤트와 현재 이벤트의 시간간격
  warmed_up::Bool                     # 웜업 됐는지 안됏는지
  next_arrival::Float64               # 다음 도착 시각
  next_completion::Float64            # 다음 완료 시각
  next_completion_info::Dict          # 다음 완료의 정보 (서버번호, AI번호)
  next_regular_update::Float64        # 다음 주기적 speed & price update 시각
  next_buffer_update::Float64         # 다음 buffer update 시각
  buffer_update_counter::Int64        # 몇 번째 buffer update인지 count
  total_cumulative_power_consumption::Float64   # 누적 전력 소모량 총합

  # constructor definition
  function VirtualDataCenter(WS::Array{Workload_Setting},
                             AI::Array{Arrival_Information},
                             SS::Array{Server_Setting},
                             warm_up_arrivals::Int64,
                             max_arrivals::Int64,
                             warm_up_time::Float64,
                             replication_time::Float64,
                             regular_update_interval::Float64,
                             S::Array{Server})
   passed_arrivals = 0       # 서비스받고 떠난 고객수
   current_time = 0.00       # 현재 시각
   inter_event_time = 0.00   # 지난 이벤트와 현재 이벤트와의 시간 간격
   warmed_up = false
   next_arrival = AI[1].arrival_time
   next_completion = typemax(Float64)
   next_completion_info = Dict()
   next_regular_update = regular_update_interval
   next_buffer_update = 0.0
   buffer_update_counter = 0
   total_cumulative_power_consumption = 0.0

    new(WS,
        AI,
        SS,
        warm_up_arrivals,
        max_arrivals,
        warm_up_time,
        replication_time,
        regular_update_interval,
        S,
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
        total_cumulative_power_consumption)
  end
end

type Plot_Information
  time_array::Array{Float64}
  speed_array::Array{Array{Float64}}
  price_array::Array{Array{Float64}}
  sojourn_time_violation_array::Array{Array{Float64}}
  sojourn_time_array::Array{Array{Float64}}
  buffer_array::Array{Array{Float64}}
  cumulative_power_consumption_array::Array{Array{Float64}}
  total_cumulative_power_consumption_array::Array{Float64}
  num_in_server_array::Array{Array{Float64}}
  file_sim_record::IOStream
  file_summarization::IOStream
  function Plot_Information(S::Array{Server}, _file_sim_record::IOStream, _file_summarization::IOStream)
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
    file_sim_record = _file_sim_record
    file_summarization = _file_summarization
    new(time_array, speed_array, price_array, sojourn_time_violation_array,sojourn_time_array, buffer_array,
        cumulative_power_consumption_array, total_cumulative_power_consumption_array, num_in_server_array,
        file_sim_record, file_summarization)
  end
end
