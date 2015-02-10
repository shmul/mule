------------------------------------
-- Daily algo, Matlab version 38 ---
------------------------------------
require 'helpers'
require 'fdi/statisticsBasic'
--require 'statisticsBasic'

-- costants
local INTERVAL = 86400
local REF_TIME = 1357344000
local WEEK = 7

-- parameters
local DRIFT = 1
local THRESHOLD = 4
local SPIKE_THRESHOLD = 3
local LOGNORMAL_SHIFT = 150
local CYCLE_FORGETTING_FACTOR = 0.3
local TREND_FORGETTING_FACTOR = 0.05
local SD_FORGETTING_FACTOR = 0.2
local MAX_TREND = 0.1
local MIN_SD = 0.15
local MAX_SD = 1
local MAX_DEV = 2.5
local SD_RANGE = 2
local SD_ON_ALARM = 2
local STABILITY_PERIOD = 4

-- initial model
local INIT_SD = 0.2
local INIT_M = math.log(LOGNORMAL_SHIFT)

function calculate_fdi_days(times_, values_)

  local step = 0

  -- samples model
  local primaryCycle = {}
	local trend = 0
	local sdCycle = {}

  -- change model
  local upperCusum = 0
  local lowerCusum = 0
  local upperCusumAno = 0
  local lowerCusumAno = 0
  local secondaryCycle = {}
  local stateCycle	= {}
	local errCycle ={}
  local alarmPeriod = 0

  local function iter(timestamp_, value_)

		-- lua optimization
    local insert = table.insert
    local remove = table.remove
    local log = math.log
    local abs = math.abs
    local max = math.max
    local min = math.min
    local sqrt = math.sqrt
    local floor = math.floor
    local ceil = math.ceil
		local exp = math.exp


		step = step + 1
    local tval = log(LOGNORMAL_SHIFT + value_)
    local ii = (timestamp_ - REF_TIME) / INTERVAL
    local hh = (ii % WEEK) + 1
		local est
		local err

    if(step <= WEEK) then

      primaryCycle[hh] = tval
			secondaryCycle[hh] = INIT_M
			errCycle[hh] = 0
			stateCycle[hh] = 0
			sdCycle[hh] = INIT_SD
      est = tval
      err = 0

      if(step == WEEK) then
        local cycValue = median(primaryCycle)
        for kk = 1,WEEK	 do
				  primaryCycle[kk] = cycValue
				end
      end

    else

      est = primaryCycle[hh] + trend
      if(est < INIT_M) then
        est = INIT_M
      end
      err = tval - est
		  remove(errCycle, 1)
      insert(errCycle, err)

			local opt = 0
      if(stateCycle[hh] > 0) then
        local secondest = secondaryCycle[hh] + trend
        if(secondest < INIT_M) then
            secondest = INIT_M
        end
        local seconderr = tval - secondest

        if(abs(seconderr) < abs(err)) then
            est = secondest
            err = seconderr
            opt = 1
        end
      end

      local upperCusumTemp = max(0, upperCusum + (err/sdCycle[hh] - DRIFT))
      local lowerCusumTemp = min(0, lowerCusum + (err/sdCycle[hh] + DRIFT))

      upperCusumAno = max(0, upperCusumAno + (err/sdCycle[hh] - DRIFT))
      lowerCusumAno = min(0, lowerCusumAno + (err/sdCycle[hh] + DRIFT))


      if((upperCusumTemp > THRESHOLD) or (lowerCusumTemp < -THRESHOLD) or (abs(err)/sdCycle[hh] > SPIKE_THRESHOLD)) then

        secondaryCycle[hh] = tval
        stateCycle[hh] = 1

			  local minerr = errCycle[1+WEEK-STABILITY_PERIOD]
			  local maxerr = errCycle[1+WEEK-STABILITY_PERIOD]
				local sumerr = errCycle[1+WEEK-STABILITY_PERIOD]
			  for kk=2+WEEK-STABILITY_PERIOD,WEEK do
			    if(errCycle[kk] < minerr) then minerr = errCycle[kk] end
				  if(errCycle[kk] > maxerr) then maxerr = errCycle[kk] end
					sumerr = sumerr + errCycle[kk]
		    end
			  local range = maxerr - minerr
        if(range/sdCycle[hh] < SD_RANGE) then
          local jump = sumerr/STABILITY_PERIOD
          for hhj = 1,WEEK do
            primaryCycle[hhj] = primaryCycle[hhj] + jump
            errCycle[hhj] = errCycle[hhj] - jump
            stateCycle[hhj] = 1
          end
		    end

		    alarmPeriod = alarmPeriod + 1

      else

        if(stateCycle[hh] == 1) then

				  if(opt == 1) then
				    secondaryCycle[hh] = CYCLE_FORGETTING_FACTOR * secondaryCycle[hh] + (1 - CYCLE_FORGETTING_FACTOR) * tval
				    stateCycle[hh] = 2;

				  else
				    primaryCycle[hh] = CYCLE_FORGETTING_FACTOR * primaryCycle[hh]+ (1 - CYCLE_FORGETTING_FACTOR) * tval
				    stateCycle[hh] = 0
				  end

		    elseif(stateCycle[hh] == 2) then

				  if(opt == 1) then
				    primaryCycle[hh] = CYCLE_FORGETTING_FACTOR * secondaryCycle[hh] + (1 - CYCLE_FORGETTING_FACTOR) * tval
					  stateCycle[hh] = 0
				  else
            primaryCycle[hh] = CYCLE_FORGETTING_FACTOR * primaryCycle[hh] + (1 - CYCLE_FORGETTING_FACTOR) * tval
					  stateCycle[hh] = 0
				  end

		    else

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

		    if(alarmPeriod > 0) then
				  upperCusumAno = upperCusumTemp
				  lowerCusumAno = lowerCusumTemp
		    end

		    alarmPeriod = 0

		    upperCusum = upperCusumTemp
		    lowerCusum = lowerCusumTemp

      end


      -- update sd
      if(alarmPeriod <= SD_ON_ALARM) then
        local ub = MAX_DEV * sdCycle[hh]
			  local dev
		    if(err > ub) then
				  dev = ub
		    elseif(err < -ub) then
		      dev = -ub
		    else
				  dev = err
		    end
		    sdCycle[hh] = sqrt((1-SD_FORGETTING_FACTOR)*sdCycle[hh]^2 + SD_FORGETTING_FACTOR*dev^2)
        if(sdCycle[hh] < MIN_SD) then
            sdCycle[hh] = MIN_SD
		    end
		    if(sdCycle[hh] > MAX_SD) then
          sdCycle[hh] = MAX_SD
		    end
		  end

    end


		local alert = step > 2*WEEK and alarmPeriod > 0
		local ano = 0
		if(alert) then
				if(err > 0) then
						ano = min(1000, floor(upperCusumAno + 0.5))
				else
						ano = max(-1000, floor(lowerCusumAno + 0.5))
				end
		end

		local iterResult = {timestamp_, alert, exp(est) - LOGNORMAL_SHIFT, ano}

    return iterResult

  end -- of iter

	----------------------------------------------------------

  local result = {}

  local range = #times_
  if range ~= #values_ then
    loge('Size of time ponits and value points must equal')
    return {}
  end

  -- detect changes
	local insert = table.insert
  for ii=1,range do
    local iterResult = iter(times_[ii], values_[ii])
		insert(result, iterResult)
  end

  return result

end
