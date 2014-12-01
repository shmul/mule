---------------------------------------
-- Minutely algo, Matlab version 03 ---
---------------------------------------
require 'helpers'
require 'fdi/statisticsBasic'
--require 'statisticsBasic'

-- costants
local INTERVAL = 300
local REF_TIME = 1357344000 + 72 * 7 * 86400

-- parameters
local DRIFT = 2
local THRESHOLD = 10
local FORGETTING_FACTOR = 0.15
local LOGNORMAL_SHIFT = 150
local MAX_ALARM_PERIOD = 4
local MIN_SD = 0.05
local SD_EST_PERIOD = 28
local INIT_PERIOD = 24

-- initial model
local INIT_SD = 0.15
local INIT_R = 0.2
local INIT_M = math.log(LOGNORMAL_SHIFT)


function calculate_fdi_minutes(times_, values_)

  local step = 0

  -- samples model
  local m = INIT_M
  local sd = INIT_SD

  -- change model
  local upperCusum = 0
  local lowerCusum = 0
	local devWindow = {}
  local alarmPeriod = 0
	local lastRef = INIT_M
	local a1 = 0

	-- lua optimization
  local insert = table.insert
	local remove = table.remove

  local function iter(timestamp_, value_)

		step = step + 1

		local tval = math.log(LOGNORMAL_SHIFT + value_)
    local ii = (timestamp_ - REF_TIME) / INTERVAL
    local y = tval
		local anoRaw = math.abs(y - (m + a1)) / sd

		local err = 0
    if(alarmPeriod < MAX_ALARM_PERIOD) then
		  err =  y - (m + a1)
      local upperCusumTemp = math.max(0, upperCusum + (err - DRIFT * sd))
      local lowerCusumTemp = math.min(0, lowerCusum + (err + DRIFT * sd))
      if(((upperCusumTemp > THRESHOLD * sd) or (lowerCusumTemp < -THRESHOLD * sd))) then
        alarmPeriod = alarmPeriod + 1;
      else
        if(alarmPeriod == 0) then
          upperCusum = upperCusumTemp
          lowerCusum = lowerCusumTemp
        else -- (alarmPeriod > 0)
          upperCusum = 0
          lowerCusum = 0
          alarmPeriod = 0
        end

        -- update m
        local newm = m + a1 + FORGETTING_FACTOR * err
        local newa1 = a1 + FORGETTING_FACTOR^2 * err
        m = newm
        a1 = newa1
      end

    else -- (alarmPeriod == MAX_ALARM_PERIOD)
      upperCusum = 0
      lowerCusum = 0
      alarmPeriod = 0

      m = y

			lastRef = m
    end


		-- update sd
		if(alarmPeriod == 0) then
		  remove(devWindow, 1)
		  insert(devWindow, err)
		  local devInd = {}
			local trDevWindow = {}
			for ii = 1,SD_EST_PERIOD do
		    devInd[ii] = true
				trDevWindow[ii] = devWindow[ii]
      end

      while true do
        local stop = true
        local mu = mean(trDevWindow)
        local sig = std(trDevWindow)
        if(sig == 0) then
          break
        end
				for ii,value in pairs(devWindow) do
				  if(devInd[ii] and (math.abs((value - mu)/sig) >= 2)) then
						devInd[ii] = false
						stop = false
				  end
				end
				trDevWindow = {}
        for ii = 1,SD_EST_PERIOD do
				  if(devInd[ii]) then
            insert(trDevWindow, devWindow[ii])
				  end
        end
        if(stop) then
          break
        end
		  end

      local sdx = std(trDevWindow) * SD_EST_PERIOD / #trDevWindow;
      sd = math.sqrt((1-FORGETTING_FACTOR)*sd^2 + FORGETTING_FACTOR*sdx^2);
      if(sd < MIN_SD) then
        sd = MIN_SD
      end
		end

		local alert = step > INIT_PERIOD and alarmPeriod > 0
		local ano = 0
		if(step > INIT_PERIOD and alarmPeriod > 0) then
		    if(anoRaw > 4 * THRESHOLD) then
						ano = 3
				elseif(anoRaw < THRESHOLD) then
						ano = 1
				else
						ano = 2
				end
		end

		local iterResult = {alert, ano}

		return iterResult
  end

	-- initialize
	local initDev = INIT_SD * math.sqrt(27/28)
	for ii = 1,SD_EST_PERIOD do
		devWindow[ii] = initDev * ((-1)^ii)
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
