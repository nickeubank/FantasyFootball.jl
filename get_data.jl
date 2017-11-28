using Requests
using DataFrames
using JLD

import Requests: get, post, put, delete, options

# File that defines `api_key` as my FantasyData api key.
# Excluded from git repo for obvious reasons.
include("api_key.jl")

key_header = Dict("Ocp-Apim-Subscription-Key" => api_key)

######
# Get all game dates
######

date_output = get("https://api.fantasydata.net/v3/nfl/stats/JSON/Schedules/2017REG";
            headers=key_header)
parsed_dates = Requests.json(date_output)
game_dates = Set()
key_format = DateFormat("YYYYMMdd")
for d in parsed_dates
   if typeof(d["Date"]) != Void
      date = Date(d["Date"], DateFormat("y-m-dTH:M:S"))
      date = uppercase(Dates.format(date, "YYYY-u-dd"))
      push!(game_dates, (d["Week"], date))
   end
end

###
# Seed entry
###
week, game_date = pop!(game_dates)

raw = get("https://api.fantasydata.net/v3/nfl/stats/JSON/DailyFantasyPoints/$game_date";
          headers=key_header)
processed = Requests.json(raw)

filtered = map(z -> filter((x,v) -> x in ["Name", "PlayerID", "Position", "Team", "FantasyPointsPPR"], z), processed)
map(z -> merge!(z, Dict("Week" => week)), filtered)
df = DataFrame(filtered[1])
for j in 2:length(filtered)
   push!(df, filtered[j])
end

###
# Full loops
###
for date_tuple in game_dates
       game_date = date_tuple[2]
       week = date_tuple[1]
       raw = get("https://api.fantasydata.net/v3/nfl/stats/JSON/DailyFantasyPoints/$game_date";
                 headers=key_header)
       processed = Requests.json(raw)
       filtered = map(z -> filter((x,v) -> x in ["Name", "PlayerID", "Position", "Team", "FantasyPointsPPR"], z), processed)
       map(z -> merge!(z, Dict("Week" => week)), filtered)


       for j in 1:length(filtered)
          push!(df, filtered[j])
       end
end
unique!(df)

JLD.save("player_stats_2017.jld", "players", df)
