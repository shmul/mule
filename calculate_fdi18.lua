
-- parameters
local D = 1
local Bu = 1.5
local Bd = 5
local alfa = 0.1
local beta = 0.05
local gama = 0.1
local delta = 0.2
local M = 3
local burnPeriod = 4
local initPeriod = 7
local refTime = 1357344000
local interval = 86400

-- model
local m = 0
local r = 0
local dev = 0
local su = 0
local sd = 0
local inBurnPeriod = 0
local last = 0
local mt = 0
local rt = 0
local alert = 0
local err = 0



local function initialize(timestamp_, initSeries_)

	local ii = (timestamp_ - refTime) / interval
	alert = 0

	local initSeries = {}
	for ii = 1,initPeriod do
		table.insert(initSeries, math.log(M + 1 + initSeries_[ii]))
	end

	local mwa = {}
	local mna = {}

	for jj,v in ipairs(initSeries) do
		if((((ii-initPeriod)+jj) % 7) < 2) then
			table.insert(mwa,v)
		else
			table.insert(mna, v)
		end
	end

	table.sort(mwa)
	table.sort(mna)
	local n = 0
	if (#mwa % 2 == 0) then n = (mwa[#mwa/2] + mwa[(#mwa/2)+1] ) / 2 else n = mwa[math.ceil(#mwa/2)] end
	if (#mna % 2 == 0) then m = (mna[#mna/2] + mna[(#mna/2)+1] ) / 2 else m = mna[math.ceil(#mna/2)] end

	r = 0
	if((n > 0) and (m>n)) then
		r = m - n
	end

	dev = math.log(1+delta)

	su = 0
	sd = 0

	intializing = false
	initSeries = {}
	inBurnPeriod = 0

end


local function iter(timestamp_, value_, initSeries_)

	local ii = (timestamp_ - refTime) / interval
	alert = 0

	local tval = math.log(M + 1 + value_)

	local y = tval
	if((ii % 7) < 2) then
		y = tval + r
	end

	if(inBurnPeriod > 0) then
		inBurnPeriod = inBurnPeriod - 1
		local errt = y - mt
		if((errt < (D + Bu) * dev) and (errt > -(D + Bd) * dev)) then
			m = mt
			inBurnPeriod = 0
		else
			alert = 1
		end
	end

	err = y - m;

	su = math.max(0, su + (err - D * dev))
	sd = math.min(0, sd + (err + D * dev))

	if(((su > Bu * dev) or (sd < -Bd * dev))) then
		if(inBurnPeriod == 0) then
			inBurnPeriod = burnPeriod
			mt = m
			rt = r
		end

		m = m + err

		su = 0
		sd = 0
		alert = 1

	else

		if((ii%7) < 2) then
			r = gama * (m - tval) + (1 - gama) * r
		end
		m = m + alfa * err
	end
end


function calculate_fdi(epoh_time_, interval_, graph_)

	local result = {}

	assert(interval_ == 86400, "Current version supports only 86400 (day) interval")

	local size = #graph_

	local min = 2000000000
	local max = 0
	for _,v in ipairs(graph_) do
		local t = v[3]
		if(t > max) then max = t end
		if((t < min) and (t > 1370044800)) then min = t end
	end

	local range = 1 + (max - min) / interval
	if(range < initPeriod) then return end

	local times = {}
	local values = {}
	for ii=1,range do
		times[ii] = min + interval * (ii-1)
		values[ii] = 0
	end



	local ind = 0
	for _,v in ipairs(graph_) do
		local ind = (v[3] - min) / interval
		if(ind >= 0) then
			values[ind+1] = v[1]
		end
	end

	--result["times"] = times
	--result["values"] = values
	local initSeries = {}
	for ii=1,initPeriod do
		table.insert(initSeries, values[ii])
	end
	initialize(times[initPeriod], initSeries)

	for ii=initPeriod+1,range do
		iter(times[ii], values[ii], {})
		local x = {times[ii], alert}
		table.insert(result, x)
	end

	return result


end



