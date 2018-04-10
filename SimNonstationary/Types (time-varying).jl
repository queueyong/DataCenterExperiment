# type definitions
type Server_Setting
  γ::Float64
  Γ::Float64
  K::Float64
  α::Float64
  n::Int64
  δ::Float64
  ϵ::Float64
  x_0::Float64
  p_0::Float64
  Apps::Tuple
end

type Workload_Setting
  instant_demand::Float64

  inter_arrival_distribution::String
  mean_inter_arrival::Float64
  rate_inter_arrival::Function # non-homogeneous arrival rate function
  scv_inter_arrival::Float64
  std_inter_arrival::Float64

  workload_distribution::String
  mean_workload::Float64
  scv_workload::Float64
  std_workload::Float64
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

  num_in_server::Int64               # 서버안의 일감의 수
  indices_in_server::Tuple           # 서버안의 일감들의 번호들?
  κ::Float64                         # 서버의 버퍼 크기
  WIP::Array{Arrival_Information}    #서버안에 있는 일감을 담는 배열

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
    new(previous_speed,
        current_speed,
        previous_price,
        current_price,
        previous_remaining_workload,
        current_remaining_workload,
        num_in_server,
        indices_in_server,
        κ,
        WIP)
  end
end

type VirtualDataCenter
  ## These variables are set directly by the creator
  AI::Array{Arrival_Information}   # Arrival_Information을 담는 배열
  SS::Array{Server_Setting}        # Server_Setting을 담는 배열
  warm_up_arrivals::Int64          # 웜업 arrival의 수
  max_arrivals::Int64              # 최대 arrival의 수
  S::Array{Server}                 # type Server 담는 배열

  ## Internal variables - Set by constructor
  passed_arrivals::Int64           # 서비스받고 떠난 일감의 수 (이게 25만개가 되면 시뮬레이션 종료)
  current_time::Float64            # 현재 시각
  inter_event_time::Float64        # 지난이벤트와 현재 이벤트의 시간간격
  warmed_up::Bool                  # 웜업 됐는지 안됏는지
  next_arrival::Float64            # 다음 도착 시각
  next_completion::Float64         # 다음 완료 시각
  next_completion_info::Dict       # 다음 완료의 정보 (서버번호, AI번호)
  next_regular_update::Float64     # 다음 주기적 speed & price update 시각

  # constructor definition
  function VirtualDataCenter(AI::Array{Arrival_Information},
                             SS::Array{Server_Setting},
                             warm_up_arrivals::Int64,
                             max_arrivals::Int64,
                             S::Array{Server})
   passed_arrivals = 0       # 서비스받고 떠난 고객수
   current_time = 0.00       # 현재 시각
   inter_event_time = 0.00   # 지난 이벤트와 현재 이벤트와의 시간 간격
   warmed_up = false
   next_arrival = AI[1].arrival_time
   next_completion = typemax(Float64)
   next_completion_info = Dict()
   next_regular_update = 0.01

    new(AI,
        SS,
        warm_up_arrivals,
        max_arrivals,
        S,
        passed_arrivals,
        current_time,
        inter_event_time,
        warmed_up,
        next_arrival,
        next_completion,
        next_completion_info,
        next_regular_update)
  end
end
