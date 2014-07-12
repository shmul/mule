require 'calculate_fdi_days_22'

-- costants
local INTERVAL = 86400
local MIN_SIGNAL_SIZE = 334

function calculate_fdi(epoch_time_, interval_, graph_)

		assert(interval_ == INTERVAL, 'Current version supports only 86400 (day) interval')

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


		if(range < MIN_SIGNAL_SIZE) then
				local dqw = MIN_SIGNAL_SIZE - range
				for ii = 1,MIN_SIGNAL_SIZE do
						times[ii] = min + INTERVAL * (ii - 1 - dqw)
						values[ii] = 0
        end
				min = min - INTERVAL * dqw
		else
				for ii=1,range do
						times[ii] = min + INTERVAL * (ii-1)
						values[ii] = 0
				end
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
