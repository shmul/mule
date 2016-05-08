require 'fdi/dailyAlg'
require 'fdi/hourlyAlg'
require 'fdi/minutelyAlg'
require 'fdi/secondlyAlg'
require 'helpers'

-- costants
local DAY_INTERVAL = 86400
local HOUR_INTERVAL = 3600
local MINUTES_INTERVAL = 60
local SECONDS_INTERVAL = 1
local BUF_SIZES = {730,2160,864,864,0}

-- the callbacks are for day,hour,minute, other
function fdi_interval_index(interval_)
  if interval_ >= DAY_INTERVAL then
	  return 1
	elseif interval_ >= HOUR_INTERVAL then
	  return 2
  elseif interval_ >= MINUTES_INTERVAL then
	  return 3
  elseif interval_ >= SECONDS_INTERVAL then
	  return 4
	end
  return 5
end

function calculate_fdi(epoh_time_, interval_, graph_)

  -- prepare time and value series
  local size = #graph_
	local bufSize = BUF_SIZES[fdi_interval_index(interval_)]

  local max = 0
  for _,v in ipairs(graph_) do
    local t = v[3]
    if(t > max) then max = t end
  end

  local atleastmin = max - (bufSize-1) * interval_
  local min = 2000000000
	for _,v in ipairs(graph_) do
    local t = v[3]
		if((t < min) and (t >= atleastmin)) then min = t end
  end

	bufSize = 1 + (max - min) / interval_

  local times = {}
  local values = {}

  for ii=1,bufSize do
    times[ii] = min + interval_ * (ii-1)
    values[ii] = 0
  end

  for _,v in ipairs(graph_) do
    local ind = (v[3] - min) / interval_
    if(ind >= 0) then
      values[ind+1] = v[1]
    end
  end

  return ({
    function() return calculate_fdi_days(times, values) end,
    function() return calculate_fdi_hours(times, values) end,
    function() return calculate_fdi_minutes(times, values) end,
    function() return calculate_fdi_seconds(times, values) end,
    function()
      logw('calculate_fdi - no match for passed interval',interval_)
                   return nil
                 end
    })[fdi_interval_index(interval_)]()

end
