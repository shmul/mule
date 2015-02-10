require 'calculate_fdi'

local filePath = './fdi/fixtures/graphs_of_interest.txt'
--local filePath = './fixtures/graphs_of_interest.txt'

local matlab = {
[1] = { [1] = {80, 42239, -6}, [2] = {102, 37801, -5}, [3] = {207, 23328, 1}, [4] = {281, 20979, 3}, [5] = {292, 20218, -2}, [6] = {405, 35815, 1}, [7] = {421, 35849, 1}, [8] = {486, 21609, -5}, [9] = {493, 20865, -5}, [10] = {494, 20865, -10}, [11] = {496, 20661, 1}, [12] = {522, 17250, -5}, [13] = {576, 15594, 3}, [14] = {588, 15877, -5}, [15] = {589, 15877, -9}, [16] = {640, 27489, -5}, [17] = {757, 19122, -5}, [18] = {782, 17864, 1}, [19] = {843, 13034, -1}, [20] = {844, 13034, 3}, [21] = {863, 15570, -3}},
[2] = { [1] = {92, 3, 1}, [2] = {93, 3, 2}},
[3] = { [1] = {292, 2555, -1}, [2] = {428, 4922, 1}, [3] = {473, 2860, 1}, [4] = {478, 3843, -1}, [5] = {481, 3301, -1}},
[4] = { [1] = {434, 6125551, 1}, [2] = {863, 2243842, -1}},
[5] = { [1] = {199, 97, 1}, [2] = {200, 97, 2}, [3] = {486, 51, 1}, [4] = {489, 88, 1}, [5] = {490, 88, 1}, [6] = {491, 88, 2}, [7] = {492, 88, 2}, [8] = {774, 45, 1}, [9] = {775, 45, 2}, [10] = {776, 45, 2}, [11] = {779, 77, 1}},
[6] = { [1] = {199, 4037, 1}, [2] = {200, 4037, 2}, [3] = {203, 4778, 1}, [4] = {240, 2646, 1}, [5] = {241, 2646, 2}, [6] = {242, 2646, 2}, [7] = {292, 4986, -2}, [8] = {475, 5282, 1}, [9] = {535, 3134, 1}, [10] = {774, 2388, 1}, [11] = {779, 3614, 1}},
[7] = { [1] = {198, 2865, 1}, [2] = {199, 2865, 1}, [3] = {425, 4288, 1}, [4] = {426, 4288, 1}, [5] = {427, 4288, 2}, [6] = {428, 4288, 2}, [7] = {473, 3230, 1}, [8] = {474, 3230, 2}, [9] = {475, 3230, 2}, [10] = {486, 2626, 1}, [11] = {534, 2751, 1}, [12] = {774, 2110, 1}, [13] = {775, 2110, 1}},
[8] = { [1] = {292, 236, -1}, [2] = {515, 99, 1}},
[9] = {},
[10] = {},
[11] = {},
[12] = { [1] = {801, 2, 1}},
[13] = { [1] = {293, 39194, -2}},
[14] = { [1] = {697, 3, 1}},
[15] = { [1] = {42, 103, 1}, [2] = {48, 223, 2}, [3] = {49, 223, 3}, [4] = {50, 223, 5}, [5] = {51, 223, 7}, [6] = {55, 1893, -2}, [7] = {56, 1893, -4}, [8] = {57, 1893, -5}, [9] = {58, 1893, -7}, [10] = {605, 119, 1}, [11] = {618, 560, 2}, [12] = {619, 560, 2}, [13] = {620, 560, 3}, [14] = {621, 560, 4}, [15] = {627, 1876, -1}, [16] = {632, 1332, -2}, [17] = {633, 1332, -2}},
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
						assert(matlab[zz][tdind][2] == math.floor(value[3]+0.5), string.format('failed test estimated: signal num = %d, alert num = %d, got %d instead of %d', zz, tdind, math.floor(value[3]+0.5), matlab[zz][tdind][2]))
						assert(matlab[zz][tdind][3] == value[4], string.format('failed test ano-measure: signal num = %d, alert num = %d, got %d instead of %d', zz, tdind, value[4], matlab[zz][tdind][3]))
				end
			end
      assert(tdind == table.getn(matlab[zz]), string.format('failed test: signal num = %d, entries num = %d, expected = %d',zz, tdind, table.getn(matlab[zz])))
		end
	end
end





