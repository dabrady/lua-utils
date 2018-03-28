-- Provide the ability to encapsulate the extensions into a different table.
local _,_,module = ...
module = module or math
assert(type(module) == 'table', 'must provide a table to extend')

-- Round the given number to the given number of decimal places.
function module.round(num, numPlaces)
  local mult = 10^(numPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- Degree/radian conversions
function module.toRadians(degrees)
  return degrees * math.pi / 180;
end
function module.toDegrees(radians)
  return radians * 180 / math.pi;
end

-----------
return module
