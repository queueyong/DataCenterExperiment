cd(dirname(Base.source_path()))
using Distributions, JuMP, Ipopt, PyPlot
include("Types (time-varying).jl")
include("Functions (time-varying).jl")


const WARM_UP_ARRIVALS = 50000
const MAX_ARRIVALS = 250000
# For recording
f = open("sim_record.txt" , "w")
f2 = open("summarization.txt" , "w")
# For plotting
speed_array = Array{Float64}[]
price_array = Array{Float64}[]
# For summarizing
sojourn_time_array = Array{Float64}[]
# main part #

# Initialization
WS = workload_setter()
SS = server_setter()
S = server_creater(SS,WS)
AI = arrival_generator()
vdc = VirtualDataCenter(AI, SS, WARM_UP_ARRIVALS, MAX_ARRIVALS, S)

# Run
run_to_end(vdc)

# Plotting Speeds and Prices
x = linspace(0,99999,100000)
y = Float64[]
for i in 1:100000
  push!(y, vdc.S[1].κ)
end
plt = PyPlot

plt.figure()
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == 6
    plt.ylabel("Speed (workload/time)",fontsize=10)
  end
  plt.yticks(linspace(0,300,31))
  plt.xticks([0,10000])
  # plt.ylim(0,250)
  plt.ylim(140,200)
  plt.xlim(0,10000)
  plt.plot(x,speed_array[j][1:100000],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
  plt.plot(x,y,linewidth=1.0,linestyle="--", color = "blue")
  #plt.plot(x,y,linewidth=2.0,linestyle="--",color="black")
end
plt.savefig("Long-run server speeds.pdf")

plt.figure()
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=10)
  plt.xlabel("Time",fontsize=6)
  if j == 1 || j == 6
    plt.ylabel("Price",fontsize=10)
  end
  plt.xticks([1,50000])
  plt.plot(x,price_array[j][1:100000],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=6)
end
plt.savefig("Long-run server prices.pdf")


# Write summarization
for j = 1:10
  println(f2, "P[W_$j>=δ_$j]: $(sum(sojourn_time_array[j])/length(sojourn_time_array[j]))")
end


# Closing
close(f2)
close(f)
