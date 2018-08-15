cd(dirname(@__FILE__))
include("../../functions_distribution.jl")
include("./types_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).jl")
include("./functions_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).jl")
include("../../job_generators.jl")
include("./solvers_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).jl")
using PyPlot

const MAX_ARRIVALS = 200000
const WARM_UP_ARRIVALS = 50000
const RUNNING_TIME = 2000.0
const WARM_UP_TIME = 0.3*RUNNING_TIME
const REGULAR_UPDATE_INTERVAL = 0.01
const NUM_REPLICATION = 10000

SS = readServerSettingsData("../../server_settings.csv")
WS = readWorkloadSettingsData("../../workload_settings.csv")
S = constructServers(SS,WS)
J = generateStationaryJobs(WS, RUNNING_TIME)
dc = DataCenter(SS, WS, J, S, REGULAR_UPDATE_INTERVAL, WARM_UP_ARRIVALS, MAX_ARRIVALS, WARM_UP_TIME, RUNNING_TIME)

#speed,routing = setOptimalPolicy(dc)
file_record = open("./result/record_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).txt" , "w")
file_summary = open("./result/summary_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).txt" , "w")
PD = Plot_Data(S, file_record, file_summary)
run_to_end(dc, PD, RUNNING_TIME, WARM_UP_TIME)

# Write summarization
println(file_summary, "Total Cumulative Power Consumption: $(dc.total_cumulative_power_consumption)")

println(file_summary, " ")
println(file_summary, "Tail probability of the response time")
for j = 1:length(SS)
  println(file_summary, "P[R_$j>=δ_$j]: $(sum(PD.sojourn_time_violation_array[j])/length(PD.sojourn_time_array[j]))")
end
println(file_summary, " ")
println(file_summary, "Mean response time")
for j = 1:length(SS)
  println(file_summary, "E[R_$j]: $(sum(PD.sojourn_time_array[j])/length(PD.sojourn_time_array[j]))")
end
println(file_summary, " ")
println(file_summary, "The number of jobs completed")
for j = 1:length(SS)
  println(file_summary, "Server $j: $(length(PD.sojourn_time_array[j]))")
end

println(file_summary, " ")
println(file_summary, "Buffer size")
for j = 1:length(SS)
  println(file_summary, "κ_$j: $(dc.S[j].κ)")
end

# Closing IOStreams
close(file_summary)
close(file_record)

# Plotting Speeds and Prices
x = PD.time_array
plt = PyPlot

## Speed plot for each server
plt.figure(figsize = (12,8))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == Int(length(S)/2)+1
    plt.ylabel("Speed (workload/time)",fontsize=10)
  end
  plt.ylim(0,120)
  plt.plot(x,PD.speed_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.plot(x,PD.buffer_array[j][1:length(x)],linewidth=1.0,linestyle="--", color = "blue")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/server_speed_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).pdf")
#plt.close()

## Number of jobs for each server
plt.figure(figsize = (12,8))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == Int(length(S)/2)+1
    plt.ylabel("Number of jobs",fontsize=10)
  end
  plt.ylim(0,10)
  plt.plot(x,PD.num_in_server_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/server_queue_length_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).pdf")
#plt.close()


## Price plot for each server
plt.figure(figsize = (15,10))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == Int(length(S)/2)+1
    plt.ylabel("Price",fontsize=10)
  end
  plt.plot(x,PD.price_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/server_price_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).pdf")

## Cumulative power plot for each server
plt.figure(figsize = (15,10))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == Int(length(S)/2)+1
    plt.ylabel("Cumulative Power Consumption",fontsize=10)
  end
  plt.plot(x,PD.cumulative_power_consumption_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/server_cumulative_power_consumption_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).pdf")


## Total cumulative power plot
plt.figure(figsize = (16,12))
plt.title("Energy Consumption", fontsize = 32)
# plt.xticks([1:100])
plt.plot(x, PD.total_cumulative_power_consumption_array[1:length(x)], linewidth=1.0, linestyle="-",color="red")
plt.xlabel("Time",fontsize=32)
plt.ylabel("Total Cumulative Power Consumption",fontsize=32)
plt.tick_params(labelsize=20)
plt.savefig("./result/total_cumulative_power_consumption_(DynamicSpeedScaling_MinPriceRouting_ConstantBuffer).pdf")
