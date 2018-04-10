cd(dirname(@__FILE__))
include("../../functions_distribution.jl")
include("./optpol_types.jl")
include("./optpol_functions.jl")
include("../../job_generators.jl")
include("../../solvers.jl")

const MAX_ARRIVALS = 200000
const WARM_UP_ARRIVALS = 50000
const RUNNING_TIME = 2000.0
const WARM_UP_TIME = 0.3*RUNNING_TIME
const REGULAR_UPDATE_INTERVAL = 0.01
const NUM_REPLICATION = 10000

REPLICATION = 10000
SS = readServerSettingsData("../../server_settings.csv")
WS = readWorkloadSettingsData("../../workload_settings.csv")
S = constructServers(SS,WS)
x, y = solveCentralized(SS, WS, S)
file_record = open("./result/record_violation_prob_MCSimulation.txt" , "w")
for i in 1:REPLICATION
    tic()
    println("Replication $i")
    J = generateStationaryJobs(WS, RUNNING_TIME)
    S = constructServers(SS,WS)
    dc = DataCenter(SS, WS, J, S, REGULAR_UPDATE_INTERVAL, WARM_UP_ARRIVALS, MAX_ARRIVALS, WARM_UP_TIME, RUNNING_TIME)
    MSD = MCSim_Summary_Data(length(S))
    setOptimalPolicy(dc, x, y)
    run_replication_MCSim(dc, MSD, RUNNING_TIME, WARM_UP_TIME)
    writeRecord(file_record, MSD, dc)
    toc()
end
close(file_record)
file_sum = open("./result/sum_MCSimlation.txt" , "w")
writeViolationProb_MCSim(file_sum, file_record)
close(file_sum)
