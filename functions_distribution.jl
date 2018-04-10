using Distributions

function Erlang_generator(μ::Any, scv::Any)
 return Erlang(Int(1/scv),μ*scv)
end

function LogNormal_generator(μ::Any, scv::Any)
 return LogNormal(log(μ)-(log(scv+1)/2),sqrt(log(scv+1)))
end

function scv(dist::Distribution)
 return var(dist)/mean(dist)^2
end

function Distribution_generator(str_dist::String, μ::Any, scv::Any)
 if str_dist ∈ ("EXP", "Exponential")
  return (Exponential(μ) , "EXP(mean$(μ)scv1.0", "Exponential (θ = $μ)")
 elseif str_dist ∈ ("ER", "Erlang")
  p = params(Erlang_generator(μ,scv))
  return (Erlang_generator(μ,scv) , "ER(mean$(μ)scv$(scv))", "Erlang (α = $(p[1]), θ = $(p[2]))")
 elseif str_dist ∈ ("LN", "Lognormal")
  p = params(LogNormal_generator(μ,scv))
  return (LogNormal_generator(μ,scv) , "LN(mean$(μ)scv$(scv))", "LogNormal(μ = $(p[1]), σ = $(p[2]))")
 end
end

function desired_scv_for_dist(str_dist::String)
 if str_dist == "ER"
  return 0.5
 elseif str_dist == "LN"
  return 2.0
 elseif str_dist == "EXP"
  return 1.0
 end
end

function string_to_dist(short_name::String)
 if short_name == "ER"
  return Erlang(2,1/2)
 elseif short_name == "LN"
  return LogNormal(-(log(3)/2),sqrt(log(3)))
 elseif short_name == "EXP"
  return Exponential(1.0)
 end
end
