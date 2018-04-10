using PyPlot
include("./Types (alg vs opt).jl")
include("./Functions (alg vs opt).jl")

# main (opt)
WS = workload_setter()
SS = server_setter()
S = server_creater(SS,WS)

## Declare model
m = Model(solver = IpoptSolver())

## Set variables
@variable(m, y[i = 1:length(WS), j = 1:length(SS)] >= 0)
@variable(m, x[i = 1:length(SS)])
for j in 1:length(SS)
  setlowerbound(x[j], SS[j].γ)
  setupperbound(x[j], SS[j].Γ)
end
## Set objective function
@NLobjective(m, Min, sum(SS[j].K + SS[j].α*x[j]^SS[j].n for j in 1:length(SS)))
#@NLobjective(m, Min, 150+250+220+150+300+350+220+350+400+700+0.3333*x[1]^3+0.2*x[2]^3+x[3]^3+0.6667*x[4]^3+0.8*x[5]^3+0.4*x[6]^3+0.4286*x[7]^3+0.5*x[8]^3+0.6*x[9]^3+0.4444*x[10]^3)

## Add constraints
for j in 1:length(SS)
  aff = AffExpr()
  for i in 1:length(WS)
    if in(i,SS[j].Apps) == true
      push!(aff, 1.0, y[i,j])
    end
  end
  @constraint(m, aff + S[j].κ  <= x[j])
end

for i in 1:length(WS)
  aff = AffExpr()
  for j in 1:length(SS)
    if in(i, SS[j].Apps) == true
      push!(aff, 1.0, y[i,j])
    end
  end
  @constraint(m, aff == WS[i].instant_demand)
end

## Solve the problem
print(m)
solve(m)
println("Obj = $(getobjectivevalue(m))")
for i in 1:length(SS) println("x[$i] = $(getvalue(x[i]))") end

# main (alg)
const ITERATION = 1000
WS = workload_setter()
SS = server_setter()
S = server_creater(SS,WS)
# For plotting
R = Record(Array{Float64}[], Array{Float64}[], Float64[])
for j = 1:length(S)
  push!(R.speed_array, Float64[])
  push!(R.price_array, Float64[])
end
iterate(SS, S , WS, ITERATION, R)

# Plotting Speeds and Prices and Energy consumption
x = linspace(1,ITERATION,ITERATION)
y = Float64[]
for i in 1:ITERATION
  push!(y, S[1].κ)
end
plt = PyPlot

plt.figure(figsize = (16,12))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=16)
  plt.xlabel("Iteration",fontsize=10)
  if j == 1 || j == 6
    plt.ylabel("Speed (workload/time)",fontsize=16)
  end
  plt.yticks(linspace(0,100,11))
  plt.xticks([1,ITERATION])
  plt.ylim(0,100)
  plt.plot(x,R.speed_array[j][1:ITERATION],linewidth=1.0,linestyle="-",color="red")
  plt.plot(x,y,linewidth=1.0,linestyle="--", color = "blue")
  plt.tick_params(labelsize=10)
  #plt.plot(x,y,linewidth=2.0,linestyle="--",color="black")
end
plt.savefig("Instantaneous server speeds.pdf")

plt.figure(figsize = (16,12))
for j in 1:length(S)
  plt.subplot(2,5,j)
  plt.title("Server $j", fontsize=16)
  plt.xlabel("Iteration",fontsize=10)
  if j == 1 || j == 6
    plt.ylabel("Price",fontsize=16)
  end
  plt.xticks([1,ITERATION])
  plt.plot(x,R.price_array[j][1:ITERATION],linewidth=1.0,linestyle="-",color="red")
  plt.tick_params(labelsize=10)
end
plt.savefig("Instantaneous server prices.pdf")

plt.figure(figsize = (16,12))
plt.title("Energy Consumption", fontsize = 32)
x = linspace(1,ITERATION,ITERATION)
# plt.xticks([1:100])
plt.plot(x, R.obj_array[1:ITERATION], linewidth=1.0, linestyle="-",color="red")
plt.xlabel("Iterations",fontsize=32)
plt.ylabel("Objective value",fontsize=32)
plt.tick_params(labelsize=20)
plt.savefig("Energy consumption.pdf")
