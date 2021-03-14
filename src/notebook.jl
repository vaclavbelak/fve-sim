### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ a844dad2-8036-11eb-370b-7d3a859cdbb0
begin
	import Pkg
	Pkg.activate(mktempdir())
	Pkg.add(["CSV", "DataFrames", "Gadfly", "HTTP"])
	using CSV
	using DataFrames
	using Gadfly
	using Printf: @sprintf
	using Statistics: mean
	import HTTP
end

# ╔═╡ 1593295c-8037-11eb-335f-5369e91a98d6
begin
	function readdata(dataset::String; installedpower:: Float64, includedhours:: UnitRange{Int64})
		res = HTTP.get("https://raw.githubusercontent.com/vaclavbelak/fve-sim/master/data/$(dataset).csv")	
		data = CSV.read(IOBuffer(String(res.body)), DataFrame, skipto=19, header=18)
		filter!(row -> row.Month ≠ "Totals", data)
		data.Hour = parse.(Int8, data.Hour)
		filter!(row -> row.Hour in includedhours, data)
		rename!(data, ["AC System Output (W)" => "one_kwp_yield"])
		select!(data, [:Month, :Day, :one_kwp_yield])
		data.Month = parse.(Int8, data.Month)
		data.Day = parse.(Int8, data.Day)
		data.Yield = data.one_kwp_yield .* installedpower ./ 1000

		return data
	end
	##
	function stats(prod, month; tuv = 8, household = 2, aku = 16, off_season = 5:8)
		n = length(prod)
		# % days covered
		house_cov = sum(prod .>= household) / n
		tuv_cov = sum(prod .>= (household + tuv)) / n
		# consumption
		house_used = household .+ min.(0, prod .- household) # subtract what's missing
		tuv_used = tuv .+ min.(0, prod .- house_used .- tuv)
		if month[1] in off_season
			overall_cov = sum(prod .>= (household + tuv)) / n
			unused_prod = sum(max.(0, prod .- (household + tuv)))
			aku_used = 0
		else
			overall_cov = sum(prod .>= (household + tuv + aku)) / n
			unused_prod = sum(max.(0, prod .- (household + tuv + aku)))
			aku_used = aku .+ min.(0, prod .- house_used .- tuv_used .- aku)
		end
		roundsum = abs∘round∘sum
		return (house_cov = house_cov,
				tuv_cov = tuv_cov,
				overall_cov = overall_cov,
				overall_util = (sum(prod) - unused_prod) / sum(prod),
				overall_used = sum(prod) - unused_prod,
				overall_prod = sum(prod),
				unused_prod = unused_prod,
			    house_used = roundsum(house_used),
				tuv_used = roundsum(tuv_used),
				aku_used = roundsum(aku_used))
	end
end

# ╔═╡ 4717ca7c-81a5-11eb-29c5-8727baeec27f
begin
	dataset = "klodzko" # praha,bielsko-biala,klodzko 
	vt = 4.3
	nt = 2.3
	house = 2 # 0
	tuv =  8
	aku = 0
	hours = 8:18
	off_season = 6:8
	wpp = 9.6 # Kc/Wp
	fc = 30000 # fixed costs in CZK
	power = 8 * 0.45 # add 10% to match IBC simulation
end

# ╔═╡ d2ff2cc0-8037-11eb-11e3-c94d9b244503
begin
	data = readdata(dataset; installedpower = power, includedhours = hours)
	data = groupby(data, [:Month, :Day])
	data = combine(data, :Yield .=> sum => :Yield)

	data_stats = combine(groupby(data, :Month), [:Yield, :Month] => ((y, m) -> stats(y, m; aku = aku, household = house, tuv = tuv, off_season = off_season)) => AsTable)
end

# ╔═╡ 773ca88e-803e-11eb-1934-73f0fae4bd21
@sprintf "Overall utilisation: %.2f" sum(data_stats.overall_used) / sum(data_stats.overall_prod)

# ╔═╡ 880fcf6a-803e-11eb-35f4-a3ce0816a965
@sprintf "Production: %u kWh" sum(data_stats.overall_prod)

# ╔═╡ 8f48824a-803e-11eb-1165-af2b7d1ae0cc
@sprintf "Usage: %u kWh" sum(data_stats.overall_used)

# ╔═╡ b8f4e1f8-8334-11eb-3a85-5153a2b4e692
@sprintf "Unused: %u kWh" sum(data_stats.unused_prod)

# ╔═╡ 136be666-81db-11eb-1414-735a5e0a6387
@sprintf "TUV: %u kWh" sum(data_stats.tuv_used)

# ╔═╡ 581bd134-81db-11eb-0e7e-ff4f96fc6d8b
@sprintf "AKU: %u kWh" sum(data_stats.aku_used)

# ╔═╡ 63aed53c-81db-11eb-2668-9525c52d3384
@sprintf "House: %u kWh" sum(data_stats.house_used)

# ╔═╡ 92bd0734-834a-11eb-36ab-13e99ef9d347
@sprintf "Savings: %u CZK" sum(data_stats.house_used) * vt + sum(data_stats.tuv_used .+ data_stats.aku_used) * nt

# ╔═╡ 62ba9fae-8408-11eb-1517-35958b46f86d
@sprintf "Repayment: %.1f years" (fc + wpp * power * 1000) / (sum(data_stats.house_used) * vt + sum(data_stats.tuv_used .+ data_stats.aku_used) * nt) 

# ╔═╡ 8339434c-8181-11eb-3220-bbc7901d898c
plot(stack(data_stats[:, [:Month, :house_cov, :tuv_cov, :overall_cov]],
		   [:house_cov, :tuv_cov, :overall_cov]),
	 x = :Month, y = :value, color = :variable, Geom.bar(position = :dodge), Guide.xticks(ticks = 1:12), Guide.yticks(ticks = 0.0:0.1:1.0), Guide.title("Coverage"), Guide.ylabel("Coverage Fraction"))

# ╔═╡ c15f35be-81a4-11eb-3c00-d392ab902b69
plot(stack(data_stats[:, [:Month, :house_used, :tuv_used, :aku_used, :unused_prod]],
		   [:house_used, :tuv_used, :aku_used, :unused_prod]),
	 x = :Month, y = :value, color = :variable, Geom.bar(position = :stack), Guide.xticks(ticks = 1:12), Guide.title("Usage"), Guide.ylabel("kWh"))

# ╔═╡ 40391c90-81cc-11eb-1d94-b767c611a16f
plot(data_stats, x = :Month, y = :overall_util, Geom.line(), Guide.xticks(ticks = 1:12), Guide.yticks(ticks = .1:.1:1), Guide.title("Overall utilisation"), Guide.ylabel("Utilisation Fraction"))

# ╔═╡ 5123e2e0-8242-11eb-0f10-b9a34d00c6fa
begin 
	function agg_stats(power, hours, aku, house, tuv, off_season)
		data = readdata(joinpath(datafile); installedpower = power, includedhours = hours)
		data = groupby(data, [:Month, :Day])
		data = combine(data, :Yield .=> sum => :Yield)

		data_stats = combine(groupby(data, :Month), [:Yield, :Month] => ((y, m) -> stats(y, m; aku = aku, household = house, tuv = tuv, off_season = off_season)) => AsTable)
		return (installed_power = power,
				overall_util = sum(data_stats.overall_used) / sum(data_stats.overall_prod),
				overall_prod = sum(data_stats.overall_prod),
				overall_used = sum(data_stats.overall_used),
				overall_unused = sum(data_stats.unused_prod),
				overall_tuv = sum(data_stats.tuv_used),
				overall_aku = sum(data_stats.aku_used),
				overall_house = sum(data_stats.house_used),
				overall_tuv_cov = mean(data_stats.tuv_cov),
				summer_tuv_cov = mean(data_stats.tuv_cov[off_season]),
				savings = sum(data_stats.house_used) * vt + sum(data_stats.tuv_used .+ data_stats.aku_used) * nt,
				repayment = (fc + wpp * 1000 * power) / (sum(data_stats.house_used) * vt + sum(data_stats.tuv_used .+ data_stats.aku_used) * nt))
	end
	data_stats_overall = DataFrame(map(p -> agg_stats(p, hours, aku, house, tuv, off_season), 1:.1:6))
	
end

# ╔═╡ 968733c8-8249-11eb-3957-c362e6b7b7c4
plot(data_stats_overall, x = :installed_power, y = :overall_util, Geom.line(), xintercept = [power], Guide.title("Utilisation vs Installed Power"), Guide.XLabel("kWp"), Guide.YLabel("Utilisation"), Geom.vline(color = "red"))

# ╔═╡ 37ba30f2-838e-11eb-2b69-5d7d19578962
plot(data_stats_overall, x = :installed_power, y = :summer_tuv_cov, xintercept = [power], Geom.line(), Guide.title("Summer TUV Coverage"), Guide.XLabel("kWp"), Guide.YLabel("Coverage"), Geom.vline(color = "red"))

# ╔═╡ f6f12b60-83d6-11eb-2265-d71a734d4542
plot(data_stats_overall, x = :installed_power, y = :savings, Geom.point, xintercept = [power], Guide.title("Savings"), Guide.XLabel("kWp"), Guide.YLabel("CZK"), Geom.vline(color = "red"))

# ╔═╡ 11c11c3c-83d7-11eb-11f3-6978e534b270
begin
	data_stats_overall.marginal_savings = vcat(missing, diff(data_stats_overall.savings))
	plot(data_stats_overall, x = :installed_power, y = :marginal_savings, xintercept = [power], yintercept = [wpp * 100 / 10], Geom.point, Guide.title("Marginal Savings"), Guide.XLabel("kWp"), Guide.YLabel("CZK"), Geom.vline(color = "red"), Geom.hline(color = "green"))
end

# ╔═╡ 8ea3eedc-8409-11eb-2210-a38c2a578c70
plot(data_stats_overall, x = :installed_power, y = :repayment, Geom.line, xintercept = [power], Guide.title("Repayment"), Guide.XLabel("kWp"), Guide.YLabel("years"), Geom.vline(color = "red"))

# ╔═╡ e99042b4-824a-11eb-3158-396b0fbdc647
plot(stack(data_stats_overall[:, [:installed_power, :overall_used, :overall_unused]], [:overall_used, :overall_unused]),
	layer(x = :installed_power, y = :value, color = :variable, Geom.bar(position = :stack), order = 1),
	layer(xintercept = [power], Geom.vline(color = "red"), order = 2),
	Guide.XLabel("kWp"), Guide.YLabel("kWh"), Guide.title("Total Used and Unused"))

# ╔═╡ 129d4892-824c-11eb-3b33-d9664d168255
plot(stack(data_stats_overall[:, [:installed_power, :overall_aku, :overall_house, :overall_tuv, :overall_unused]], [:overall_aku, :overall_house, :overall_tuv, :overall_unused]),
	layer(x = :installed_power, y = :value, color = :variable, Geom.bar(position = :stack), order = 1),
	layer(xintercept = [power], Geom.vline(color = "red"), order = 2),
	Guide.XLabel("kWp"), Guide.YLabel("kWh"), Guide.title("Used by TUV, AKU, and house"), Guide.XTicks(ticks = 1:6))

# ╔═╡ Cell order:
# ╟─a844dad2-8036-11eb-370b-7d3a859cdbb0
# ╟─1593295c-8037-11eb-335f-5369e91a98d6
# ╠═4717ca7c-81a5-11eb-29c5-8727baeec27f
# ╟─d2ff2cc0-8037-11eb-11e3-c94d9b244503
# ╟─773ca88e-803e-11eb-1934-73f0fae4bd21
# ╟─880fcf6a-803e-11eb-35f4-a3ce0816a965
# ╟─8f48824a-803e-11eb-1165-af2b7d1ae0cc
# ╟─b8f4e1f8-8334-11eb-3a85-5153a2b4e692
# ╟─136be666-81db-11eb-1414-735a5e0a6387
# ╟─581bd134-81db-11eb-0e7e-ff4f96fc6d8b
# ╟─63aed53c-81db-11eb-2668-9525c52d3384
# ╟─92bd0734-834a-11eb-36ab-13e99ef9d347
# ╟─62ba9fae-8408-11eb-1517-35958b46f86d
# ╟─8339434c-8181-11eb-3220-bbc7901d898c
# ╟─c15f35be-81a4-11eb-3c00-d392ab902b69
# ╟─40391c90-81cc-11eb-1d94-b767c611a16f
# ╟─5123e2e0-8242-11eb-0f10-b9a34d00c6fa
# ╟─968733c8-8249-11eb-3957-c362e6b7b7c4
# ╟─37ba30f2-838e-11eb-2b69-5d7d19578962
# ╟─f6f12b60-83d6-11eb-2265-d71a734d4542
# ╟─11c11c3c-83d7-11eb-11f3-6978e534b270
# ╟─8ea3eedc-8409-11eb-2210-a38c2a578c70
# ╟─e99042b4-824a-11eb-3158-396b0fbdc647
# ╟─129d4892-824c-11eb-3b33-d9664d168255
