
-- costants
local INTERVAL = 86400
local REF_TIME = 1357344000
local WEEK = 7

-- parameters
local DRIFT = 1
local UPPER_THRESHOLD = 2.5
local LOWER_THRESHOLD = 5
local DAYLY_FORGETTING_FACTOR = 0.1
local WEEKLY_FORGETTING_FACTOR = 0.5
local WEEKLY_UPDATE_LIMIT = 0.5
local LOGNORMAL_SHIFT = 3
local MAX_ALARM_PERIOD = 4
local INIT_PERIOD = 7
local MIN_SD = 0.2
local MAX_SD = 0.8
local SD_RATIO = 2.5
local SD_PERIOD = 28


function calculate_fdi_days(times_, values_)

		-- samples model
		local m = 0
		local r = 0
		local sd = MIN_SD

		-- change model
		local upperCusum = 0
		local lowerCusum = 0
		local alarmPeriod = 0

		-- history window
		local preChangeMean = 0
		local errosWindow = {}
		local weeklyWindow = {}


		local function median(array_)
				local sorted = {}
				for _,value in pairs(array_) do
						table.insert(sorted, value)
				end
				table.sort(sorted)
				local res
				local len = #sorted
				if (len % 2 == 0) then res = (sorted[len/2] + sorted[(len/2)+1] ) / 2 else res = sorted[math.ceil(len/2)] end
				return res
		end

		local function initialize(timestamp_)

				local ii = (timestamp_ - REF_TIME) / INTERVAL
				local mwa = {}
				local mna = {}

				for jj,v in ipairs(weeklyWindow) do
						if((((ii-INIT_PERIOD)+jj) % 7) < 2) then
								table.insert(mwa,v)
						else
								table.insert(mna, v)
						end
				end

				local n = median(mwa)
				m = median(mna)

				r = 0
				if((n > 0) and (m > n)) then
						r = m - n
				end

				for jj,v in ipairs(weeklyWindow) do
						if((((ii-INIT_PERIOD)+jj) % 7) < 2) then
								table.insert(errosWindow,v + r - m)
						else
								table.insert(errosWindow, v - m)
						end
				end

				sd = MIN_SD;

				upperCusum = 0;
        lowerCusum = 0;

				weeklyWindow = {}
        alarmPeriod = 0;
		end


		local function iter(timestamp_, value_)

				local ii = (timestamp_ - REF_TIME) / INTERVAL
				local alert = false
				table.insert(weeklyWindow, value_)

				local y
				if((ii % 7) < 2) then
						y = value_ + r
				else
						y = value_
				end

				local qerr = 0

				if(alarmPeriod > 1) then
						alarmPeriod = alarmPeriod - 1
						local errt = y - preChangeMean
						local err = y - m
						if((errt < (DRIFT + UPPER_THRESHOLD) * sd) and (errt > -(DRIFT + LOWER_THRESHOLD) * sd) and (math.abs(errt) < math.abs(err))) then
								m = preChangeMean
								alarmPeriod = 0
						else
								alert = true
						end
						qerr = SD_RATIO * math.min(err^2, errt^2)

				elseif(alarmPeriod == 1) then
						m = y
						alarmPeriod = 0

				else
						local err = y - m
						upperCusum = math.max(0, upperCusum + (err - DRIFT * sd));
						lowerCusum = math.min(0, lowerCusum + (err + DRIFT * sd));
						if(((upperCusum > UPPER_THRESHOLD * sd) or (lowerCusum < -LOWER_THRESHOLD * sd))) then
								alarmPeriod = MAX_ALARM_PERIOD;
								preChangeMean = m;
								upperCusum = 0;
								lowerCusum = 0;
								m = y;
								alert = true;
						else
								m = m + DAYLY_FORGETTING_FACTOR * err;
						end

						qerr = SD_RATIO*err^2;

				end

				if(#errosWindow == SD_PERIOD) then
						table.remove(errosWindow, 1)
				end
				table.insert(errosWindow, qerr)

				local medQerr = median(errosWindow)

				sd = math.sqrt((1-DAYLY_FORGETTING_FACTOR)*sd^2 + DAYLY_FORGETTING_FACTOR*medQerr)
				if(sd < MIN_SD) then
						sd = MIN_SD
				end
				if(sd > MAX_SD) then
						sd = MAX_SD
				end

				if(#weeklyWindow == WEEK) then
						local mwa = {}
						local mna = {}
						for jj,v in ipairs(weeklyWindow) do
								if((((ii-WEEK)+jj) % 7) < 2) then
										table.insert(mwa,v)
								else
										table.insert(mna, v)
								end
						end
						local mout = median(mna)
						local n = median(mwa)
						local rout = 0;
						if((n > 0) and (mout > n)) then
								rout = mout - n
						end

						if((rout - r) > WEEKLY_UPDATE_LIMIT) then
								r = r + WEEKLY_FORGETTING_FACTOR*WEEKLY_UPDATE_LIMIT
						elseif((rout - r) <  - WEEKLY_UPDATE_LIMIT) then
								r = r - WEEKLY_FORGETTING_FACTOR*WEEKLY_UPDATE_LIMIT
						else
								r = r + WEEKLY_FORGETTING_FACTOR * (rout - r)
						end
						weeklyWindow = {};
				end

				return alert
		end


		local result = {}

		local range = #times_
		assert(range == #values_, 'Size of time ponits and value points must equal')

		if(range < INIT_PERIOD) then return end

		-- intialize model
		for ii=1,INIT_PERIOD do
				table.insert(weeklyWindow, math.log(LOGNORMAL_SHIFT + 1 + values_[ii]))
				local x = {times_[ii], false}
				table.insert(result, x)
		end
		initialize(times_[INIT_PERIOD])

		-- detect changes
		for ii=INIT_PERIOD+1,range do
				alert = iter(times_[ii], math.log(LOGNORMAL_SHIFT + 1 + values_[ii]))
				local x = {times_[ii], alert}
				table.insert(result, x)
		end

		return result

end



