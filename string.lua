-- Provide the ability to encapsulate the extensions into a different table.
local _,_,module = ...
module = module or string
assert(type(module) == 'table', 'must provide a table to extend')

--- Recipes for common string manipulations in Lua ---

-- Returns true if the given string starts with another, otherwise returns false.
function module.startsWith(str, query)
  return string.sub(str, 1, string.len(query)) == query
end

-- Returns true if the given string ends with another, otherwise returns false.
function module.endsWith(str, query)
  return query == '' or string.sub(str, -string.len(query)) == query
end

-- Removes initial and trailing whitespace
-- @see http://lua-users.org/wiki/StringTrim, 'trim6' implementation
function module.trim(str)
  return str:match'^()%s*$' and '' or str:match'^%s*(.*%S)'
end

-- Given a string, one presumably composed of a sequence of tokens joined by underscores,
-- returns the given string with the underscores replaced by a single space, along with the number of
-- underscores replaced.
function module.unchain(str)
  return str:gsub('_', ' ')
end

-----------
return module
