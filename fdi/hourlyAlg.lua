-------------------------------------
-- Hourly algo, Matlab version 18 ---
-------------------------------------
require 'helpers'

-- costants
local  INTERVAL = 3600
local  REF_TIME = 1357344000 + 60 * 7 * 86400
local  DAY = 24
local  WEEK = 7

-- parameters
local  DRIFT = 1
local  THRESHOLD_UP = 6
local  THRESHOLD_DOWN = 10
local  FORGETTING_FACTOR = 0.1
local  LOGNORMAL_SHIFT = 4
local  MAX_ALARM_PERIOD = 2
local  MAX_SD_CHANGE = 0.05
local  MIN_SD = 0.2
local  PHASE_DEV = 2
local  INIT_PERIOD = 60

-- initial model
local INIT_SD = 0.2
local INIT_M = math.log(LOGNORMAL_SHIFT)


function calculate_fdi_hours(times_, values_)

  local step = 0

  -- samples model
	local sd = INIT_SD
	local nday = {INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M}
  local wday = {INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M, INIT_M}

  -- change model
  local upperCusum = 0
  local lowerCusum = 0
  local ndayap = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	local wdayap = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}

	local insert = table.insert

  local function iter(timestamp_, value_)

	  step = step + 1

    local tval = math.log(LOGNORMAL_SHIFT + value_)
    local ii = (timestamp_ - REF_TIME) / INTERVAL
    local hh = (ii % DAY) + 1
    local dd = math.floor((ii % (WEEK*DAY)) / DAY) + 1

		local alarmPeriod
    if(dd > 2) then
      alarmPeriod = ndayap[hh]
    else
      alarmPeriod = wdayap[hh]
    end

    local err = 1000
    for jj = ii-PHASE_DEV,ii+PHASE_DEV do
      local hhj = (jj % DAY) + 1
      local ddj = math.floor((jj % (WEEK*DAY)) / DAY) + 1
      local est
			if(ddj > 2) then
        est = nday[hhj]
      else
        est = wday[hhj]
      end
      if(math.abs(tval-est) < math.abs(err)) then
        err = tval-est
      end
    end

    local anoRaw = math.abs(err) / sd

    if(alarmPeriod < MAX_ALARM_PERIOD) then
      local upperCusumTemp = math.max(0, upperCusum + (err - DRIFT * sd))
      local lowerCusumTemp = math.min(0, lowerCusum + (err + DRIFT * sd))
      if(((upperCusumTemp > THRESHOLD_UP * sd) or (lowerCusumTemp < -THRESHOLD_DOWN * sd))) then
        alarmPeriod = alarmPeriod + 1

      else
        if(alarmPeriod == 0) then
            upperCusum = upperCusumTemp
            lowerCusum = lowerCusumTemp
        else -- if(0 < alarmPeriod)
            upperCusum = 0
            lowerCusum = 0
            alarmPeriod = 0
        end

        -- update sd
        local sdtemp = math.sqrt((1-FORGETTING_FACTOR)*sd^2 + FORGETTING_FACTOR*err^2)
        if(sdtemp - sd > MAX_SD_CHANGE) then
				  sd = sd + MAX_SD_CHANGE
        elseif(sdtemp - sd < -MAX_SD_CHANGE) then
          sd = sd - MAX_SD_CHANGE
        else
          sd = sdtemp
        end
        if(sd < MIN_SD) then
          sd = MIN_SD
        end

        -- update nday, wday
        if(dd > 2) then
          nday[hh] = nday[hh] + FORGETTING_FACTOR * err
        else
          wday[hh] = wday[hh] + FORGETTING_FACTOR * err
        end
      end

    else
      local r = 0
      if(nday[hh] > wday[hh]) then
        r = nday[hh] - wday[hh]
      end
      if(dd > 2) then
        nday[hh] = tval
        wday[hh] = tval - r
      else
        wday[hh] = tval
        nday[hh] = wday[hh] + r
      end

      upperCusum = 0
      lowerCusum = 0
      alarmPeriod = 0
    end

    if(dd > 2) then
      ndayap[hh] = alarmPeriod
    else
      wdayap[hh] = alarmPeriod
    end

		local alert = step > INIT_PERIOD and alarmPeriod > 0
		local ano = 0
		if(step > INIT_PERIOD and alarmPeriod > 0) then
				if(anoRaw > 4 * THRESHOLD_UP) then
						ano = 3
				elseif(anoRaw < THRESHOLD_UP) then
						ano = 1
				else
						ano = 2
				end
		end

		local iterResult = {alert, ano}

    return iterResult
  end

  local result = {}

  local range = #times_
  if range ~= #values_ then
    loge('Size of time ponits and value points must equal')
    return {}
  end

  -- detect changes
  for ii=1,range do
    local iterResult = iter(times_[ii], values_[ii])
		local x = {times_[ii], iterResult[1], iterResult[2]}
    insert(result, x)
  end

  return result

end
