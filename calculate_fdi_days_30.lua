
-- costants
local INTERVAL = 86400
local REF_TIME = 1357344000
local WEEK = 7

-- parameters
local DRIFT = 1
local THRESHOLD = 4
local FORGETTING_FACTOR = 0.06
local LOGNORMAL_SHIFT = 4
local MAX_ALARM_PERIOD = 4
local MAX_SD_CHANGE = 0.017
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
  local alarmPeriod = 0
  local insert = table.insert

  local function median(array_)
    local sorted = {}
    for _,value in pairs(array_) do
      sorted[#sorted] = value
    end
    table.sort(sorted)
    local res
    local len = #sorted
    if (len % 2 == 0) then
      local i = math.min(len/2,(len/2)+1)
      res = (sorted[len/2] + sorted[i] ) / 2
    else
      res = sorted[math.ceil(len/2)]
    end
    return res
  end

  local function iter(timestamp_, value_)

    local tval = math.log(LOGNORMAL_SHIFT + value_)
    local ii = (timestamp_ - REF_TIME) / INTERVAL

    local y
    if((ii % 7) < 2) then
      y = tval + r
    else
      y = tval
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
          weeklyWindow = {}
          alarmPeriod = 0
        end

        -- update m
        m = m + FORGETTING_FACTOR * err

        -- update sd
        sdtemp = math.sqrt((1-FORGETTING_FACTOR)*sd^2 + FORGETTING_FACTOR*err^2)
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

        -- update r
        if(#weeklyWindow == WEEK) then
          table.remove(weeklyWindow, 1)
        end
        insert(weeklyWindow, tval)

        if(#weeklyWindow == WEEK) then
          mwa = {}
          mna = {}
          for jj,v in ipairs(weeklyWindow) do
            if((((ii-WEEK)+jj) % 7) < 2) then
              insert(mwa,v)
            else
              insert(mna, v)
            end
          end
          mout = median(mna)
          n = median(mwa)
          rout = 0
          if((n > 0) and (mout > n)) then
            rout = mout - n
          end
          r = r + FORGETTING_FACTOR * (rout - r)
        end
      end

    else -- (alarmPeriod == MAX_ALARM_PERIOD)
      upperCusum = 0
      lowerCusum = 0
      weeklyWindow = {}
      alarmPeriod = 0

      m = y
    end

    return (alarmPeriod > 0)
  end


  local result = {}

  local range = #times_
  if range ~= #values_ then
    loge('Size of time ponits and value points must equal')
    return {}
  end

  -- detect changes
  for ii=1,range do
    alert = iter(times_[ii], values_[ii])
    local x = {times_[ii], alert}
    insert(result, x)
  end

  return result

end
