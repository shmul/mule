------------------------------------
-- Daily algo, Matlab version 33 ---
------------------------------------
require 'helpers'
require 'fdi/statisticsBasic'

-- costants
local INTERVAL = 86400
local REF_TIME = 1357344000
local WEEK = 7

-- parameters
local DRIFT = 1
local THRESHOLD = 4
local FORGETTING_FACTOR = 0.06
local LOGNORMAL_SHIFT = 100
local MAX_ALARM_PERIOD = 4
local R_DRIFT = 1.5
local R_SAFETY = 2
local SD_EST_PERIOD = 28
local MIN_SD = 0.1

-- initial model
local INIT_SD = 0.5
local INIT_R = 0.2
local INIT_M = math.log(LOGNORMAL_SHIFT)

function calculate_fdi_days(times_, values_)

  -- samples model
  local m = INIT_M
  local r = INIT_R
  local sd = INIT_SD

  -- change model
  local upperCusum = 0
  local lowerCusum = 0
  local weeklyWindow = {}
	local devWindow = {}
  local alarmPeriod = 0
  local rPeriod = 0
	local lastRef = INIT_M

	-- downtime
	local downtime = 0
  local lastDowntime = 0

	-- lua optimization
  local insert = table.insert
	local remove = table.remove


  local function iter(timestamp_, value_)

    local tval = math.log(LOGNORMAL_SHIFT + value_)
    local ii = (timestamp_ - REF_TIME) / INTERVAL

    local y
    if((ii % 7) < 2) then
      y = tval + r
    else
      y = tval
    end

		if(value_ == 0) then
		  downtime = downtime + 1
      lastDowntime = ii
    else
      downtime = 0
    end

    if(alarmPeriod < MAX_ALARM_PERIOD) then
      local err = y - m
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
        m = m + FORGETTING_FACTOR * err
      end

    else -- (alarmPeriod == MAX_ALARM_PERIOD)
      upperCusum = 0
      lowerCusum = 0
      alarmPeriod = 0

      m = y

			lastRef = m;
		  for jj = 1,MAX_ALARM_PERIOD-1 do
        devWindow[SD_EST_PERIOD + 1 - jj] = weeklyWindow[WEEK + 1 - jj] - lastRef;
      end

    end

		-- update sd
		if(downtime == 0) then
		  remove(devWindow, 1)
		  insert(devWindow, y-lastRef)
      if(alarmPeriod == 0) then
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
    end

    -- update r
    remove(weeklyWindow, 1)
    insert(weeklyWindow, tval)

    if(ii - lastDowntime > WEEK) then
      local mwa = {}
      local mna = {}
      for jj,v in ipairs(weeklyWindow) do
        if((((ii-WEEK)+jj) % 7) < 2) then
          insert(mwa,v)
        else
          insert(mna, v)
        end
      end
      local mout = median(mna)
      local nout = median(mwa)

      local wdif = 0
      for _,value in pairs(mwa) do
        if(math.abs(value - nout) > R_SAFETY*sd) then wdif = wdif + 1 end
      end
      local ndif = 0
      for _,value in pairs(mna) do
        if(math.abs(value - mout) > R_SAFETY*sd) then ndif = ndif + 1 end
      end

      if((wdif == 0) and (ndif == 0) and (mout >= nout)) then
        local rout = mout - nout

        if(rPeriod < MAX_ALARM_PERIOD) then
          if((math.abs(rout - r) > R_DRIFT)) then
            rPeriod = rPeriod + 1
          else
            r = r + FORGETTING_FACTOR * (rout - r)
            rPeriod = 0
          end
        else
          r = rout
          rPeriod = 0
        end
      else
        rPeriod = 0
      end

		else
      if(downtime > WEEK) then
        r = 0
        rPeriod = 0
      end
    end

    return (alarmPeriod > 0)
  end



	-- initialize
	for ii = 1,WEEK do
		weeklyWindow[ii] = INIT_M
  end

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
    local alert = iter(times_[ii], values_[ii])
		local x = {times_[ii], alert}
    insert(result, x)
  end

  return result

end
