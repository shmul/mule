require 'fdi/dailyAlg'
require 'fdi/hourlyAlg'
require 'fdi/minutelyAlg'
--require 'dailyAlg'
--require 'hourlyAlg'
--require 'minutelyAlg'
require 'helpers'

-- costants
local DAY_INTERVAL = 86400
local HOUR_INTERVAL = 3600
local MINUTES_INTERVAL = 300

function calculate_fdi(epoh_time_, interval_, graph_)

  -- prepare time and value series
  local size = #graph_

	local ref = 0
  if interval_ == DAY_INTERVAL then
	  ref = 1357344000
	elseif interval_ == HOUR_INTERVAL then
	  ref = 1357344000 + 10136*3600
  elseif interval_ == MINUTES_INTERVAL then
	  ref = 1370044800
	else
	  ref = 0
  end

  local min = 2000000000
  local max = 0
  for _,v in ipairs(graph_) do
    local t = v[3]
    if(t > max) then max = t end
    if((t < min) and (t > ref)) then min = t end
  end

  local range = 1 + (max - min) / interval_

  local times = {}
  local values = {}

  for ii=1,range do
    times[ii] = min + interval_ * (ii-1)
    values[ii] = 0
  end

  for _,v in ipairs(graph_) do
    local ind = (v[3] - min) / interval_
    if(ind >= 0) then
      values[ind+1] = v[1]
    end
  end

  -- run days algorithm
	if interval_ == DAY_INTERVAL then
		return calculate_fdi_days(times, values)
  elseif interval_ == HOUR_INTERVAL then
	  return calculate_fdi_hours(times, values)
  elseif interval_ == MINUTES_INTERVAL then
	  return calculate_fdi_minutes(times, values)
  else
	  logw('calculate_fdi - current version supports only 86400 (day) or 3600 (hour) or 300 (5 minutes) intervals')
    return nil
  end

end
