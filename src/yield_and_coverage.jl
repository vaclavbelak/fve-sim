using CSV
using DataFrames

data = DataFrame(CSV.File("/Users/vaclav/Downloads/klodzsko_1.csv", skipto=19, header=18))
filter!(row -> row.Month ≠ "Totals", data)
rename!(data, ["AC System Output (W)" => "Yield"])
select!(data, [:Month, :Day, :Yield])
data.Month = parse.(Int8, data.Month)
data.Day = parse.(Int8, data.Day)

data.Yield = data.Yield .* 3

agg_data = combine(groupby(data, [:Month, :Day]), :Yield .=> sum => :Yield)
print(combine(groupby(agg_data, :Month), :Yield => (x -> (sum(x .>= 8000) / length(x), sum(x .>= 6000) / length(x)))))

using Gadfly


plot(agg_data[agg_data.Month .== 4,:], x=:Yield, Geom.density)
plot(agg_data[agg_data.Month .== 5,:], x=:Yield, Geom.density)
plot(agg_data[agg_data.Month .== 6,:], x=:Yield, Geom.density)
plot(agg_data[agg_data.Month .== 7,:], x=:Yield, Geom.density)
plot(agg_data[agg_data.Month .== 8,:], x=:Yield, Geom.density)
plot(agg_data[agg_data.Month .== 9,:], x=:Yield, Geom.density)
