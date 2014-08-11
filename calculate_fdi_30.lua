require 'calculate_fdi_days_30'

-- costants
local INTERVAL = 86400

function calculate_fdi(epoh_time_, interval_, graph_)

  if interval_~=INTERVAL then
    logw('calculate_fdi - current version supports only 86400 (day) interval')
    return nil
  end

  -- prepare time and value series
  local size = #graph_

  local min = 2000000000
  local max = 0
  for _,v in ipairs(graph_) do
    local t = v[3]
    if(t > max) then max = t end
    if((t < min) and (t > 1370044800)) then min = t end
  end

  local range = 1 + (max - min) / INTERVAL

  local times = {}
  local values = {}

  for ii=1,range do
    times[ii] = min + INTERVAL * (ii-1)
    values[ii] = 0
  end

  local ind = 0
  for _,v in ipairs(graph_) do
    local ind = (v[3] - min) / INTERVAL
    if(ind >= 0) then
      values[ind+1] = v[1]
    end
  end

  -- run days algorithm
  return calculate_fdi_days(times, values)

end
