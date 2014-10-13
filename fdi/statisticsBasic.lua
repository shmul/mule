------------------------------------
-- Basic statistical functions   ---
------------------------------------

function median(array_)
  local len = #array_
  if len == 0 then
		loge('median - array size must be greater than zero')
		return 0
  end
  local sorted = {}
  for _,value in pairs(array_) do
    table.insert(sorted, value)
  end
  table.sort(sorted)
  local res
  if (len % 2 == 0) then
    local i = len/2
    res = (sorted[i] + sorted[i+1] ) / 2
  else
    res = sorted[math.ceil(len/2)]
  end
  return res
end

function mean(array_)
  local len = #array_
  if len == 0 then
    loge('mean - array size must be greater than zero')
		return 0
  end
  local sum = 0
  for i = 1,len do
    sum = sum + array_[i]
  end
  return sum/len
end

function std(array_)
  local len = #array_
  if len <= 1 then
		loge('std - array size must be greater than one')
		return 0
  end
  local mu = mean(array_)
  local squares_sum = 0
  for i = 1,len do
    squares_sum = squares_sum + (array_[i] - mu)^2
  end
  return math.sqrt(squares_sum / (len-1))
end
