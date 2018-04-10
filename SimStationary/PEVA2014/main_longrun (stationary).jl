using Distributions, PyPlot, JuMP, Ipopt

include("./Types (stationary).jl")
include("./Functions (stationary).jl")

const MAX_ARRIVALS = 200000
const WARM_UP_ARRIVALS = 50000
#const REPLICATION_TIME = 5000.0
const REPLICATION_TIME = 5000.0
const WARM_UP_TIME = 0.3*REPLICATION_TIME
const REGULAR_UPDATE_INTERVAL = 0.01

# main part #

# Initialization
file_record = open("./result/record.txt" , "w")
file_summarization = open("./result/summarization.txt" , "w")
WS = workload_setter()
SS = server_setter()
S = server_creater(SS,WS)
AI = arrival_generator(WS,REPLICATION_TIME)
vdc = VirtualDataCenter(WS, AI, SS, WARM_UP_ARRIVALS, MAX_ARRIVALS, WARM_UP_TIME, REPLICATION_TIME, REGULAR_UPDATE_INTERVAL, S)
PI = Plot_Information(S,file_record,file_summarization)

# Run
run_to_end(vdc, PI, REPLICATION_TIME, WARM_UP_TIME)      # until a certain number of services are completed

# Write summarization
println(file_summarization, "Total Cumulative Power Consumption: $(vdc.total_cumulative_power_consumption)")
println(file_summarization, " ")
for j = 1:10
  println(file_summarization, "P[W_$j>=δ_$j]: $(sum(PI.sojourn_time_violation_array[j])/length(PI.sojourn_time_array[j]))")
end
println(file_summarization, " ")
for j in 1:10
  println(file_summarization, "E[W_$j]: $(sum(PI.sojourn_time_array[j])/length(PI.sojourn_time_array[j]))")
end
println(file_summarization, " ")
println(file_summarization, "The number of jobs completed")
for j in 1:10
  println(file_summarization, "Server $j: $(length(PI.sojourn_time_array[j]))")
end

# Closing IOStreams
close(file_summarization)
close(file_record)

# Plotting Speeds and Prices
x = PI.time_array
plt = PyPlot


## Speed plot for each server
plt.figure(figsize = (12,8))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == 6
    plt.ylabel("Speed (workload/time)",fontsize=10)
  end
#  plt.ylim(0,150)
  plt.plot(x,PI.speed_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.plot(x,PI.buffer_array[j][1:length(x)],linewidth=1.0,linestyle="--", color = "blue")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/Long-run server speeds.pdf")
plt.close()

## Number of jobs for each server
plt.figure(figsize = (12,8))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == 6
    plt.ylabel("Number of jobs",fontsize=10)
  end
  plt.plot(x,PI.num_in_server_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/Long-run number of jobs.pdf")
plt.close()

## Price plot for each server
plt.figure(figsize = (15,10))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == 6
    plt.ylabel("Price",fontsize=10)
  end
  plt.plot(x,PI.price_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/Long-run server prices.pdf")
plt.close()

## Cumulative power plot for each server
plt.figure(figsize = (15,10))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == 6
    plt.ylabel("Cumulative Power Consumption",fontsize=10)
  end
  plt.plot(x,PI.cumulative_power_consumption_array[j][1:length(x)],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("./result/Long-run server cumulative power consumption.pdf")
plt.close()

## Total cumulative power plot
plt.figure(figsize = (16,12))
plt.title("Energy Consumption", fontsize = 32)
# plt.xticks([1:100])
plt.plot(x, PI.total_cumulative_power_consumption_array[1:length(x)], linewidth=1.0, linestyle="-",color="red")
plt.xlabel("Time",fontsize=32)
plt.ylabel("Total Cumulative Power Consumption",fontsize=32)
plt.tick_params(labelsize=20)
plt.savefig("./result/Total Cumulative Power Consumption.pdf")
plt.close()
