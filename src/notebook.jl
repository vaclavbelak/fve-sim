### A Pluto.jl notebook ###
# v0.12.21

using Markdown
using InteractiveUtils

# ╔═╡ a844dad2-8036-11eb-370b-7d3a859cdbb0
begin
	using CSV
	using DataFrames
	using Gadfly
	using Printf: @sprintf
	using PlutoUI
end

# ╔═╡ 1593295c-8037-11eb-335f-5369e91a98d6
begin
	function readdata(path::String; installedpower:: Float64, includedhours:: UnitRange{Int64})
		data = DataFrame(CSV.File(path, skipto=19, header=18))
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
		season_cons = household + tuv + aku
		off_season_cons = household + tuv
		# % days covered
		house_cov = sum(prod .>= household) / n
		tuv_cov = sum(prod .>= (household + tuv)) / n
		# consumption
		house_used = household * n - sum(max.(0, household .- prod))
		tuv_used = (household + tuv) * n - sum(max.(0, (household + tuv) .- prod))
		if month[1] in off_season
			overall_cov = sum(prod .>= off_season_cons) / n
			unused_prod = sum(max.(0, prod .- off_season_cons))
			aku_used = 0
		else
			overall_cov = sum(prod .>= season_cons) / n
			unused_prod = sum(max.(0, prod .- season_cons))
			aku_used = season_cons * n - sum(max.(season_cons .- prod))
		end
		return (house_cov = house_cov,
				tuv_cov = tuv_cov,
				overall_cov = overall_cov,
				overall_util = (sum(prod) - unused_prod) / sum(prod),
				overall_used = sum(prod) - unused_prod,
				overall_prod = sum(prod),
				unused_prod = unused_prod,
			    house_used = house_used,
				tuv_used = tuv_used,
				aku_used = aku_used)
	end
end

# ╔═╡ 4717ca7c-81a5-11eb-29c5-8727baeec27f
begin
	power = 14 * 0.33
	house = 2
	tuv = 8
	aku = 16
	hours = 8:18
	off_season = 6:8
end

# ╔═╡ d2ff2cc0-8037-11eb-11e3-c94d9b244503
begin
	data = readdata(joinpath(@__DIR__, "../data/praha.csv"); installedpower = power, includedhours = hours)
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

# ╔═╡ 136be666-81db-11eb-1414-735a5e0a6387
@sprintf "TUV: %u kWh" sum(data_stats.tuv_used)

# ╔═╡ 581bd134-81db-11eb-0e7e-ff4f96fc6d8b
@sprintf "AKU: %u kWh" sum(data_stats.aku_used)

# ╔═╡ 63aed53c-81db-11eb-2668-9525c52d3384
@sprintf "House: %u kWh" sum(data_stats.house_used)

# ╔═╡ 8339434c-8181-11eb-3220-bbc7901d898c
plot(stack(data_stats[:, [:Month, :house_cov, :tuv_cov, :overall_cov]],
		   [:house_cov, :tuv_cov, :overall_cov]),
	 x = :Month, y = :value, color = :variable, Geom.bar(position = :dodge), Guide.xticks(ticks = 1:12), Guide.yticks(ticks = 0.0:0.1:1.0), Guide.title("Coverage"))

# ╔═╡ c15f35be-81a4-11eb-3c00-d392ab902b69
plot(stack(data_stats[:, [:Month, :house_used, :tuv_used, :aku_used, :unused_prod]],
		   [:house_used, :tuv_used, :aku_used, :unused_prod]),
	 x = :Month, y = :value, color = :variable, Geom.bar(position = :stack), Guide.xticks(ticks = 1:12), Guide.title("Usage"))

# ╔═╡ 40391c90-81cc-11eb-1d94-b767c611a16f
plot(data_stats, x = :Month, y = :overall_util, Geom.line(), Guide.xticks(ticks = 1:12), Guide.yticks(ticks = .1:.1:1), Guide.title("Overall utilisation"))

# ╔═╡ 5123e2e0-8242-11eb-0f10-b9a34d00c6fa
begin 
	function agg_stats(power, hours = 8:18, aku = 16, house = 2, tuv = 8, off_season = 6:8)
		data = readdata(joinpath(@__DIR__, "../data/praha.csv"); installedpower = power, includedhours = hours)
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
				overall_house = sum(data_stats.house_used))
	end
	data_stats_overall = DataFrame(map(p -> agg_stats(p, 9:18, 16), 1:.1:6))
end

# ╔═╡ 968733c8-8249-11eb-3957-c362e6b7b7c4
plot(data_stats_overall, x = :installed_power, y = :overall_util, Geom.line(), Guide.title("Utilisation vs Installed Power"), Guide.XLabel("kWp"), Guide.YLabel("Utilisation"))

# ╔═╡ Cell order:
# ╟─a844dad2-8036-11eb-370b-7d3a859cdbb0
# ╟─1593295c-8037-11eb-335f-5369e91a98d6
# ╠═4717ca7c-81a5-11eb-29c5-8727baeec27f
# ╠═d2ff2cc0-8037-11eb-11e3-c94d9b244503
# ╟─773ca88e-803e-11eb-1934-73f0fae4bd21
# ╟─880fcf6a-803e-11eb-35f4-a3ce0816a965
# ╟─8f48824a-803e-11eb-1165-af2b7d1ae0cc
# ╟─136be666-81db-11eb-1414-735a5e0a6387
# ╟─581bd134-81db-11eb-0e7e-ff4f96fc6d8b
# ╟─63aed53c-81db-11eb-2668-9525c52d3384
# ╟─8339434c-8181-11eb-3220-bbc7901d898c
# ╟─c15f35be-81a4-11eb-3c00-d392ab902b69
# ╟─40391c90-81cc-11eb-1d94-b767c611a16f
# ╟─5123e2e0-8242-11eb-0f10-b9a34d00c6fa
# ╠═968733c8-8249-11eb-3957-c362e6b7b7c4
