using CSV
using DataFrames
using Gadfly
using Dates: monthname
using Statistics: std

installedpower = 14 * 0.330
const tuv = 8
const household = 2
const aku = 16
const off_season_cons = household + tuv
const season_cons = household + tuv + aku

# parses the hourly data for 1kWp from https://pvwatts.nrel.gov/
function readdata(path::String)
    data = DataFrame(CSV.File(path, skipto=19, header=18))
    filter!(row -> row.Month ≠ "Totals", data)
    data.Hour = parse.(Int8, data.Hour)
    filter!(row -> row.Hour in 9:18, data)
    rename!(data, ["AC System Output (W)" => "one_kwp_yield"])
    select!(data, [:Month, :Day, :one_kwp_yield])
    data.Month = parse.(Int8, data.Month)
    data.Day = parse.(Int8, data.Day)
    data.Yield = data.one_kwp_yield .* installedpower ./ 1000

    return data
end

function stats(prod, month)
    n = length(prod)
    # % days covered
    tuv_cov = sum(prod .> tuv) / n
    aku_cov = sum(prod .> aku) / n
    household_cov = sum(prod .> household) / n
    if month[1] in 6:8
        overall_cov = sum(prod .> off_season_cons) / n
        unused_prod = sum(max.(0, prod .- off_season_cons))
    else
        overall_cov = sum(prod .> season_cons) / n
        unused_prod = sum(max.(0, prod .- season_cons))
    end
    return (household_cov = household_cov,
            tuv_cov = tuv_cov,
            aku_cov = aku_cov,
            overall_cov = overall_cov,
            overall_util = (sum(prod) - unused_prod) / sum(prod),
            overall_used = sum(prod) - unused_prod,
            overall_prod = sum(prod),
            unused_prod = unused_prod)
end

data = readdata(joinpath(@__DIR__, "data/praha.csv"))
data = groupby(data, [:Month, :Day])
data = combine(data, :Yield .=> sum => :Yield)

data_stats = combine(groupby(data, :Month), [:Yield, :Month] => stats => AsTable)
print(data_stats)
print("Overall utilisation: $(sum(data_stats.overall_used) / sum(data_stats.overall_prod))")
print("Production: $(sum(data_stats.overall_prod))")
print("Usage: $(sum(data_stats.overall_used))")

data = readdata(joinpath(@__DIR__, "data/klodzko.csv"))
data = groupby(data, [:Month, :Day])
data = combine(data, :Yield .=> sum => :Yield)

data_stats = combine(groupby(data, :Month), [:Yield, :Month] => stats => AsTable)
print(data_stats)
print("Overall utilisation: $(sum(data_stats.overall_used) / sum(data_stats.overall_prod))")
print("Production: $(sum(data_stats.overall_prod))")
print("Usage: $(sum(data_stats.overall_used))")

plot(filter(r -> r.Month in 6:8, data), x = :Yield, xgroup = :Month, Geom.subplot_grid(Geom.histogram))