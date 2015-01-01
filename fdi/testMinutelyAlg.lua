require 'calculate_fdi'

local filePath = './fdi/fixtures/graphs_of_interest.txt'
--local filePath = './fixtures/graphs_of_interest.txt'

local matlab = {
[1] = { [1] = {80, 3}, [2] = {102, 3}, [3] = {207, 2}, [4] = {281, 3}, [5] = {292, 3}, [6] = {405, 2}, [7] = {421, 2}, [8] = {486, 3}, [9] = {493, 3}, [10] = {494, 3}, [11] = {496, 2}, [12] = {522, 3}, [13] = {576, 3}, [14] = {588, 3}, [15] = {589, 3}, [16] = {640, 3}, [17] = {757, 3}, [18] = {782, 2}, [19] = {843, 2}, [20] = {844, 3}, [21] = {863, 3}},
[2] = { [1] = {92, 2}, [2] = {93, 2}},
[3] = { [1] = {292, 2}, [2] = {428, 1}, [3] = {473, 2}, [4] = {478, 1}, [5] = {481, 1}},
[4] = { [1] = {434, 2}, [2] = {863, 2}},
[5] = { [1] = {199, 2}, [2] = {200, 2}, [3] = {486, 2}, [4] = {489, 1}, [5] = {490, 2}, [6] = {491, 1}, [7] = {492, 2}, [8] = {774, 2}, [9] = {775, 2}, [10] = {776, 2}, [11] = {779, 1}},
[6] = { [1] = {199, 2}, [2] = {200, 1}, [3] = {203, 1}, [4] = {240, 1}, [5] = {241, 1}, [6] = {242, 1}, [7] = {292, 2}, [8] = {475, 1}, [9] = {535, 1}, [10] = {774, 2}, [11] = {779, 1}},
[7] = { [1] = {198, 1}, [2] = {199, 1}, [3] = {425, 2}, [4] = {426, 2}, [5] = {427, 2}, [6] = {428, 2}, [7] = {473, 2}, [8] = {474, 2}, [9] = {475, 2}, [10] = {486, 1}, [11] = {534, 1}, [12] = {774, 1}, [13] = {775, 1}},
[8] = { [1] = {292, 2}, [2] = {515, 2}},
[9] = {},
[10] = {},
[11] = {},
[12] = { [1] = {801, 2}},
[13] = { [1] = {293, 2}},
[14] = { [1] = {697, 2}},
[15] = { [1] = {42, 1}, [2] = {48, 2}, [3] = {49, 2}, [4] = {50, 2}, [5] = {51, 2}, [6] = {55, 2}, [7] = {56, 2}, [8] = {57, 2}, [9] = {58, 2}, [10] = {605, 1}, [11] = {618, 1}, [12] = {619, 1}, [13] = {620, 1}, [14] = {621, 1}, [15] = {627, 1}, [16] = {632, 1}, [17] = {633, 1}},
[16] = {}
}

local zz = 0

for line in io.lines(filePath) do
	local tokens = {}
	local index = 0
	for token in string.gmatch(line,"[_.%w]+") do
		index = index + 1
		tokens[index] = token
	end

	if(tokens[2] == "5m") then

		zz = zz + 1

		if(zz > 0) then

			local name = tokens[1]
			--print(name)

			local graph = {}
			local size = index/3 - 1

			for ii = 1,size do
				local triple = {}
				triple[1] = tonumber(tokens[3*ii + 1])
				triple[2] = tonumber(tokens[3*ii + 2])
				triple[3] = tonumber(tokens[3*ii + 3])
				graph[ii] = triple
			end

			local result = calculate_fdi(0, 300, graph)

			local tdind = 0
			for key,value in pairs(result) do
				if(value[2]) then
						local td = key-1
						tdind = tdind + 1
						assert(matlab[zz][tdind][1] == td, string.format('failed test alarm: signal num = %d, alert num = %d, got %d instead of %d', zz, tdind, td, matlab[zz][tdind][1]))
						assert(matlab[zz][tdind][2] == value[3], string.format('failed test level: signal num = %d, alert num = %d, got %d instead of %d', zz, tdind, value[3], matlab[zz][tdind][2]))
				end
			end
      assert(tdind == table.getn(matlab[zz]), string.format('failed test: signal num = %d, entries num = %d, expected = %d',zz, tdind, table.getn(matlab[zz])))
		end
	end
end





