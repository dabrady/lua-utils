-- Provide the ability to encapsulate the extensions into a different table.
local module = ... or table
assert(type(module) == 'table', 'must provide a table to extend')

-- Handy table formatting function. Supports arbitrary depth.
function module.format(t, depth)
  if type(t) ~= 'table' then return tostring(t) end
  depth = depth or 1

  local function tabs(n)
    local tabs = ''
    for i=0,n do
      tabs = tabs..'\t'
    end
    return tabs
  end

  local function trimTrailingNewline(s)
    return s:gsub('\n$', '')
  end

  local function walk(t, curIndentLvl, depth)
    if next(t) == nil then return '' end -- empty table check

    local tstring = '\n'
    for k,v in pairs(t) do
      local indent = tabs(curIndentLvl)
      local kstring = trimTrailingNewline(tostring(k))
      local vstring = nil
      if type(v) == 'table' and depth > 1 then
        vstring = string.format(' = table{%s%s}', walk(v, curIndentLvl + 1, depth - 1), indent)
      else
        vstring = string.format(' = %s', trimTrailingNewline(tostring(v)))
      end

      tstring = string.format("%s%s%s%s\n", tstring, indent, kstring, vstring)
    end

    return tstring
  end

  return '{'..walk(t, 0, depth)..'}'
end

-- Returns a list of the keys of the given table.
function module.keys(t)
  if type(t) ~= 'table' then return nil end

  local keys = {}
  for k,_ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

-- Returns a list of the values of the given table.
function module.values(t)
  if type(t) ~= 'table' then return nil end

  local values = {}
  for _,v in pairs(t) do
    table.insert(values, v)
  end
  return values
end

-- Executes, across a table, a function that transforms each key-value pair into a new key-value pair, and
-- concatenates all the resulting tables together.
function module.map(t, fn)
  if type(t) ~= 'table' then return nil end
  if type(fn) ~= 'function' then return nil end

  local results = {}
  for k,v in pairs(t) do
    local k,v = fn(k,v)
    results[k] = v
  end
  return results
end


-----------------
--
-- Functions of varying complexity levels to achieve
-- a table copy in Lua.
--


-- 1. The Problem.
--
-- Here's an example to see why deep copies are useful.
-- Let's say function f receives a table parameter t,
-- and it wants to locally modify that table without
-- affecting the caller. This code fails:
--
-- function f(t)
--  t.a = 3
-- end
--
-- local my_t = {a = 5}
-- f(my_t)
-- print(my_t.a)  --> 3
--
-- This behavior can be hard to work with because, in
-- general, side effects such as input modifications
-- make it more difficult to reason about program
-- behavior.


-- 2. The easy solution.

function module.copy(obj)
  if type(obj) ~= 'table' then return obj end

  -- Preserve metatables.
  local res = setmetatable({}, getmetatable(obj))

  for k, v in pairs(obj) do res[module.copy(k)] = module.copy(v) end
  return res
end

-- 3. Supporting recursive structures.
--
-- The issue here is that the following code will
-- get stuck in an infinite loop:
--
-- local my_t = {}
-- my_t.a = my_t
-- local t_copy = table.copy(my_t, true)
--
-- This happens when trying to make a copy of my_t.a,
-- which involves making a copy of my_t.a.a, which
-- involves making a copy of my_t.a.a.a, etc. The
-- recursive table my_t is perfectly legal, and it's
-- possible to make a deep_copy function that can
-- handle this by tracking which tables it has already
-- started to copy.

function module.deepCopy(obj, seen)
  -- Handle non-tables and previously-seen tables.
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end

  -- New table: mark it as seen and copy recursively.
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[module.deepCopy(k, s)] = module.deepCopy(v, s) end
  return res
end

-- Simple utility for merging two tables.
function module.merge(t1, t2)
  for k,v in pairs(t2) do t1[k] = v end
  return t1
end

-----------
return module
