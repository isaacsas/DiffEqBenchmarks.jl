using ReactionNetworkImporters
using DiffEqBase, DiffEqBiological, DiffEqJump, OrdinaryDiffEq, Plots, Statistics
plotlyjs()
fmt = :png

# parameters
networkname = "tester"
tf = 10.
# bngfname = "PATH/TO/FILE"
bngfname = joinpath(dirname(pathof(ReactionNetworkImporters)),"..","data","bcr","bcr.net")

#methods = (Direct(),DirectFW(),SortingDirect(),NRM(),DirectCR(),RSSA())
methods = (SortingDirect(),NRM(),DirectCR(),RSSA())
legs    = [typeof(method) for method in methods]
#shortlabels = [string(leg)[12:end] for leg in legs]
shortlabels = [string(leg) for leg in legs]

# get the BioNetGen reaction network
prnbng = loadrxnetwork(BNGNetwork(),string(networkname,"bng"), bngfname);
rn = prnbng.rn; u₀ = prnbng.u₀; p = prnbng.p; shortsymstosyms = prnbng.symstonames;
u0 = round.(Int, u₀)
println(typeof(u0))
addjumps!(rn,build_regular_jumps=false, minimal_jumps=true)
prob = DiscreteProblem(rn, u0, (0.,tf), p)


function run_benchmark!(t, jump_prob, stepper)
    println("    warmup")
    sol = solve(jump_prob, stepper)
    @inbounds for i in 1:length(t)
        println("  $i/$(length(t))")
        t[i] = @elapsed (sol = solve(jump_prob, stepper))
    end
end

nsims = 1
benchmarks = Vector{Vector{Float64}}()
for method in methods
    println("Benchmarking method: ", method)
    jump_prob = JumpProblem(prob, method, rn, save_positions=(false,false))
    stepper = SSAStepper()
    t = Vector{Float64}(undef,nsims)
    run_benchmark!(t, jump_prob, stepper)
    push!(benchmarks, t)
end

medtimes = Vector{Float64}(undef,length(methods))
stdtimes = Vector{Float64}(undef,length(methods))
avgtimes = Vector{Float64}(undef,length(methods))
for i in 1:length(methods)
    medtimes[i] = median(benchmarks[i])
    avgtimes[i] = mean(benchmarks[i])
    stdtimes[i] = std(benchmarks[i])
end
using DataFrames

df = DataFrame(names=shortlabels,medtimes=medtimes,relmedtimes=(medtimes/medtimes[1]),
                avgtimes=avgtimes, std=stdtimes, cv=stdtimes./avgtimes)


sa = [string(round(mt,digits=4),"s") for mt in df.medtimes]
bar(df.names,df.relmedtimes,legend=:false, fmt=fmt)
scatter!(df.names, .025 .+df.relmedtimes, markeralpha=0, series_annotations=sa, fmt=fmt)
ylabel!("median relative to Sorting Direct")
title!("BCR Network")

