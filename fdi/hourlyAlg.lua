-------------------------------------
-- Hourly algo, Matlab version 27 ---
-------------------------------------
require 'helpers'
require 'fdi/statisticsBasic'
--require 'statisticsBasic'

-- costants
local  INTERVAL = 3600
local  REF_TIME = 1357344000
local		DAY = 24
local  WEEK = 168

-- parameters
local  DRIFT = 1.2
local  THRESHOLD = 10
local  CYCLE_FORGETTING_FACTOR = 0.3
local  SD_FORGETTING_FACTOR = 0.005
local  TREND_FORGETTING_FACTOR = 0.01
local  MAX_TREND = 0.2
local  LOGNORMAL_SHIFT = 150
local  MIN_SD = 0.15
local		MAX_DEV = 3

-- initialization values
INIT_SD = 0.2

function calculate_fdi_hours(times_, values_)

  local step = 0

	-- samples model
	local primaryCycle = {}
	local secondaryCycle = {}
	local sd = INIT_SD
	local trend = 0

	-- change model
	local cycleState = {}
	local devWindow = {}
	local alarmPeriod = 0
	local upperCusum = 0
  local lowerCusum = 0
	local upperCusumAno = 0
  local lowerCusumAno = 0
  local downtime = 0


  local function iter(timestamp_, value_)

		-- lua optimization
    local insert = table.insert
    local remove = table.remove
    local log = math.log
    local abs = math.abs
    local max = math.max
    local min = math.min
    local sqrt = math.sqrt
		local exp = math.exp

	  step = step + 1

    local tval = log(LOGNORMAL_SHIFT + value_)
    local ii = (timestamp_ - REF_TIME) / INTERVAL
    local hh = (ii % WEEK) + 1
		if(value_ == 0) then
				downtime = downtime + 1
		else
				downtime = 0
		end
		local err = 0
		local est = tval

		if(step <= WEEK) then
				primaryCycle[hh] = tval
				cycleState[hh] = 0

				if(step == WEEK) then
						local cycArray = {}
						local cycValue = 0
						for jj = 1,DAY do
								for kk = 1,7 do
										cycArray[kk] = primaryCycle[jj + (kk-1) * DAY]
								end
								cycValue = median(cycArray)
								for kk = 1,7 do
										primaryCycle[jj + (kk-1) * DAY] = cycValue
								end
						end
				end

		else

		    est = primaryCycle[hh] + trend
				if(est < log(LOGNORMAL_SHIFT)) then
						est = log(LOGNORMAL_SHIFT)
				end
				err = tval - est

				if(cycleState[hh] > 0) then
						local secondest = secondaryCycle[hh] + trend
						if(secondest < log(LOGNORMAL_SHIFT)) then
								secondest = log(LOGNORMAL_SHIFT)
						end
						local seconderr = tval - secondest

						if(abs(seconderr) < abs(err)) then
								est = secondest
								err = seconderr
								local temp = primaryCycle[hh]
								primaryCycle[hh] = secondaryCycle[hh]
								secondaryCycle[hh] = temp
						end
				end

				upperCusumAno = max(0, upperCusumAno + (err - DRIFT * sd))
        lowerCusumAno = min(0, lowerCusumAno + (err + DRIFT * sd))

				local upperCusumTemp = max(0, upperCusum + (err - DRIFT * sd))
				local lowerCusumTemp = min(0, lowerCusum + (err + DRIFT * sd))

				if((upperCusumTemp > THRESHOLD * sd) or (lowerCusumTemp < -THRESHOLD * sd)) then

						secondaryCycle[hh] = tval

						if(cycleState[hh] == 0) then
								if(downtime == 0 or downtime > 2*DAY) then
										cycleState[hh] = 1
								end
								alarmPeriod = alarmPeriod + 1

						elseif(cycleState[hh] == 1) then
								cycleState[hh] = 2
								alarmPeriod = 0

								upperCusum = 0
								lowerCusum = 0

						else --(cycleState[hh] == 2)
								cycleState[hh] = 0
								alarmPeriod = 0

								primaryCycle[hh] = tval
						end

				else

						if(cycleState[hh] == 0) then
								cycleState[hh] = 0

						elseif(cycleState[hh] == 1) then
								cycleState[hh] = 2

						else --(cycleState[hh] == 2)
								cycleState[hh] = 0

						end

						if(cycleState[hh] == 0 and alarmPeriod == 0) then
								upperCusum = upperCusumTemp
								lowerCusum = lowerCusumTemp
						else
								upperCusum = 0
								lowerCusum = 0
						end

						if(alarmPeriod > 0) then
								upperCusumAno = upperCusum
								lowerCusumAno = lowerCusum
						end

						-- reset alarm
						alarmPeriod = 0

						-- update cycle
						primaryCycle[hh] = primaryCycle[hh] + trend + CYCLE_FORGETTING_FACTOR * err

						-- update trend
						trend = trend + TREND_FORGETTING_FACTOR * err
						if(trend > MAX_TREND) then
								trend = MAX_TREND
						end
						if(trend < -MAX_TREND) then
								trend = -MAX_TREND
						end

				end

		end

		-- update sd
		if(alarmPeriod < 3) then
				local dev = 0
				if(err > MAX_DEV * sd) then
						dev = MAX_DEV * sd
				elseif(err < -MAX_DEV * sd) then
						dev = -MAX_DEV * sd
				else
						dev = err
				end
				sd = sqrt((1-SD_FORGETTING_FACTOR)*sd^2 + SD_FORGETTING_FACTOR*dev^2)
				if(sd < MIN_SD) then
						sd = MIN_SD
				end
		end


		local alert = step > 2*WEEK and alarmPeriod > 0
		local ano = 0
		if(alert) then
				if(err > 0) then
						ano = upperCusumAno
				else
						ano = lowerCusumAno
				end
		end

		local iterResult = {timestamp_, alert, exp(est) - LOGNORMAL_SHIFT, ano}

    return iterResult
  end

	--------------------------------------------
	--------- Enclosing Function  --------------
	--------------------------------------------

	-- check input
  local range = #times_
	if range ~= #values_ then
    loge('Size of time ponits and value points must equal')
    return {}
  end

  -- initilialize tables
	local initEst = math.log(LOGNORMAL_SHIFT)
	for ii = 1,WEEK do
		primaryCycle[ii] = initEst
		secondaryCycle[ii] = initEst
		cycleState[ii] = 0
  end

  -- detect changes
	local result = {}
	local insert = table.insert
  for ii=1,range do
    local iterResult = iter(times_[ii], values_[ii])
		insert(result, iterResult)
  end
  return result

end
