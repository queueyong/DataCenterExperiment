using Distributions

#=
function generateNonstationaryJobs(TVWS::Array{Time_Varying_Workload_Setting}, RUNNING_TIME::Float64)

end

function generateNonstationaryJobs(TVWS::Array{Time_Varying_Workload_Setting}, MAX_ARRIVALS::Int64)

end
=#
function generateStationaryJobs(WS::Array{Workload_Setting}, RUNNING_TIME::Float64) # condition is either RUNNING_TIME or MAX_ARRIVALS
    nA = length(WS)

    random_numbers = [Float64[] for i in 1:nA]
    for i in 1:nA push!(random_numbers[i], rand(WS[i].dist_inter_arrival)) end

    k = 1
    t = 0.0
    while t < RUNNING_TIME*1.05
    for i in 1:nA
      push!(random_numbers[i], random_numbers[i][k] + rand(WS[i].dist_inter_arrival))
    end
    k += 1
    t = minimum([random_numbers[i][k] for i in 1:nA])
    end

    J = Job[]
    m = 0.0
    k = 1
    while m < RUNNING_TIME*1.01
    m = minimum([random_numbers[i][1] for i in 1:nA])
    for i in 1:nA
      if m == random_numbers[i][1]
        push!(J, Job(k, i, m, rand(WS[i].dist_jobsize), typemax(Float64)))
        shift!(random_numbers[i])
      end
    end
    k += 1
    end

    return J
end

function generateStationaryJobs(WS::Array{Workload_Setting}, MAX_ARRIVALS::Int64) # condition is either RUNNING_TIME or MAX_ARRIVALS
    nA = length(WS)

    random_numbers = [rand(WS[i].dist_inter_arrival, MAX_ARRIVALS*3) for i in 1:nA]
    k = 1
    while k < MAX_ARRIVALS*3
      for i in 1:nA
        random_numbers[i][k+1] = random_numbers[i][k] + random_numbers[i][k+1]
      end
      k += 1
    end

    J = Job[]
    m = 0.0
    k = 1
    while k < MAX_ARRIVALS*1.5
      m = minimum([random_numbers[i][1] for i in 1:nA])
      for i in 1:nA
        if m == random_numbers[i][1]
          push!(J, Job(k, i, m, rand(WS[i].dist_jobsize), typemax(Float64)))
          shift!(random_numbers[i])
        end
      end
      k += 1
    end

    return J
end
