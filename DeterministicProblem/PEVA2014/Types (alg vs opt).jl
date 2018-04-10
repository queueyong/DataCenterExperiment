# type definitions
type Server_Setting
  γ::Float64 # server speed lower bound
  Γ::Float64 # server speed upper bound
  K::Float64 # utility function parameter 1
  α::Float64 # utility function parameter 2
  n::Int64 # utility function parameter 3
  δ::Float64 # QoS parameter 1
  ϵ::Float64 # QoS parameter 2
  x_0::Float64 # initial server speed
  p_0::Float64 # initial price
  Apps::Tuple # assigned applications
end

type Workload_Setting
  instant_demand::Float64 # for instantaneous problem
  inter_arrival_distribution::String
  mean_inter_arrival::Float64
  scv_inter_arrival::Float64
  std_inter_arrival::Float64
  workload_distribution::String
  mean_workload::Float64
  scv_workload::Float64
  std_workload::Float64
end

type Server
  previous_speed::Float64
  current_speed::Float64
  previous_price::Float64
  current_price::Float64
  previous_remaining_workload::Float64 # at time t
  current_remaining_workload::Float64  # at time t+1
  κ::Float64                           # buffer
  function Server(previous_speed::Float64,
                  current_speed::Float64,
                  previous_price::Float64,
                  current_price::Float64)
    previous_remaining_workload = 0.0
    current_remaining_workload = 0.0
    κ = 0.0
    new(previous_speed,
        current_speed,
        previous_price,
        current_price,
        previous_remaining_workload,
        current_remaining_workload,
        κ)
  end
end

type Record
  speed_array::Any
  price_array::Any
  obj_array::Array{Float64}
end
