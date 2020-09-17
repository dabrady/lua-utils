--[[
TODO
- update type checking to use `assert` instead of returning nil
]]

-- Provide the ability to encapsulate the extensions into a different table.
local _,_,module = ...
module = module or table
assert(type(module) == 'table', 'must provide a table to extend')

-- Handy table formatting function. Supports arbitrary depth.
function module.format(t, options)
  -- Delegate to builtin 'tostring' for non-tabular values.
  if type(t) ~= 'table' then return tostring(t) end

  local defaults = {
    -- How deep do we follow this rabbit hole?
    depth = 1,
    -- Set the indentation level (i.e. number of tab characters) of the first format level.
    startingIndentLvl = 0,
    -- A prefix to mark tabular values
    tablePrefix = 'table'
  }
  if options then
    assert( type(options) == 'table', "format options must be a table" )
    options = table.merge(defaults, options)
  else
    options = defaults
  end

  local function tabs(n)
    local tabs = ''
    for i=1,n do
      tabs = tabs..'\t'
    end
    return tabs
  end

  local function trimTrailingNewline(s)
    return s:gsub('\n$', '')
  end

  -- Support custom `tostring` methods that accept options.
  local function toIndentedString(v, curIndentLvl)
    local meta = getmetatable(v)
    if meta and meta.__tostring then
      return meta.__tostring(v, { indent = curIndentLvl })
    else
      return nil
    end
  end

  local function walk(t, curIndentLvl, depth)
    if next(t) == nil then return '' end -- empty table check

    local tstring = '\n'
    for k,v in pairs(t) do
      local indent = tabs(curIndentLvl)
      local kstring = trimTrailingNewline(tostring(k))
      local vstring = nil

      if type(v) == 'table' and depth > 1 then
        local formattedTable = toIndentedString(v, curIndentLvl)
        if formattedTable then
          vstring = string.format(' = %s', formattedTable)
        else
          vstring = string.format(' = %s{%s%s}', options.tablePrefix, walk(v, curIndentLvl + 1, depth - 1), indent)
        end
      else
        local formattedTable = type(v) == 'table' and toIndentedString(v, curIndentLvl)
        vstring = string.format(' = %s', formattedTable or trimTrailingNewline(tostring(v)))
      end

      tstring = string.format("%s%s%s%s\n", tstring, indent, kstring, vstring)
    end

    return tstring
  end

  local startIndent = tabs(options.startingIndentLvl)
  return string.format('%s{%s%s}', startIndent, walk(t, options.startingIndentLvl + 1, options.depth), startIndent)
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

function module.isEmpty(t)
  if type(t) ~= 'table' then return nil end
  -- If there are any pairs to iterate over, the table isn't empty.
  return next(t) == nil
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

-- Turns a table inside by creating a new table whose keys are the values
-- of the original table, and whose values are the corresponding keys of
-- the original.
function module.inverse(t, gather_collisions)
  local _t = {}
  local collisions = {}

  for k,v in pairs(t) do
    if gather_collisions and _t[v] then
      if collisions[v] then
        table.insert(collisions[v], k)
      else
        collisions[v] = {k}
      end
    else
      _t[v] = k
    end
  end

  if gather_collisions then
    for k,vs in pairs(collisions) do
      table.insert(vs, _t[k])
      _t[k] = vs
    end
  end

  return _t
end

-- Returns a deduped version of `t`.
function module.uniq(t)
  local _t = {}
  local seen = {}
  for _,v in ipairs(t) do
    if not seen[v] then
      seen[v] = true
      table.insert(_t, v)
    end
  end
  return _t
end

-- Returns a subset of the given table consisting of entries matching the given list of keys.
function module.slice(t, keys)
  if not keys then
    return
  end

  local _t = {}
  for _,v in ipairs(keys) do _t[v] = t[v] end

  return _t
end

--[[
  Ordered table iterator, allow to iterate on the natural order of the keys of a table.
  @see http://lua-users.org/wiki/SortedIteration
]]
function module.orderedPairs(t, state)
  local function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in next,t do
      orderedIndex[#orderedIndex + 1] = key
    end
    table.sort( orderedIndex )
    return orderedIndex
  end

  -- Equivalent of the next function, but returns the keys in the alphabetic
  -- order. We use a temporary ordered key table that is stored in the
  -- table being iterated.
  function orderedNext(t, state)
    if state == nil then
      -- The first time, generate the index and set our initial cursor
      t.__orderedIndex = __genOrderedIndex( t )
      t.__iterationPosition = 1
    else
      -- Move the cursor
      t.__iterationPosition = t.__iterationPosition + 1
    end

    local key = t.__orderedIndex[t.__iterationPosition]
    if key then
      return key, t[key]
    end

    -- No more entries, cleanup our iterator state
    t.__orderedIndex = nil
    t.__iterationPosition = nil
    return
  end

  return orderedNext, t, nil
end

--[[
  A "list" is a dense (i.e. non-sparse) table with sequential, numerical keys, and a "length" valued at the highest key.
  NOTE: Because a list is a very specific kind of table, the cost of this judgment increases with the size of the table.
  Be wary of using this in situations where performance is critical and the table size can be quite large.

  A table with no entries is ambiguous, and you can decide what it is. This algorithm defaults
  to "not a list".

  These are NOT lists by default (you can change this):
      {}
      { [1] = nil } (NOTE: Lua says keys with nil values don't count, and therefore this is equivalent to '{}')

  These are NOT lists:
      2
      2.0
      'boo'
      false
      { [1] = 'a', b = 'c' }
      { b = 'a', [2] = 'c' }
      { a = 1, b = 2 }
      { 1, nil, 3 } (NOTE: Lua says keys with nil values don't count as entries, and this shorthand notation is
                     equivalent to { [1]=1, [2]=nil, [3]=1 }, which creates a sparse table equivalent
                     { [1]=1, [3]=3 } and is thus not a list)

  These are lists:
      { [1] = 'a', [2] = 'b' }
      { [2] = 'b', [1] = 'a' } (NOTE: It doesn't matter in what order entries are added to the table.)
      { 'a', 'b' }
      { 6, 2 }
      { {} }
]]
function module.isList(t, empty_tables_are_lists)
  -- NOTE(dabrady) Useful for explaining the results.
  local function log(...)
    -- print('[DEBUG]', ...)
  end
  do
    local empty = module.isEmpty(t)
    if empty == nil then
      -- `module.isEmpty` returns nil when its argument is not a table at all.
      log't is not a table'
      return false
    end

    -- NOTE(dabrady)
    -- A table with no entries is ambiguous, and you can decide what it is.
    -- This algorithm defaults to "not a list".
    if empty then
      -- This defaults to nil, and thus is falsey unless specified.
      if empty_tables_are_lists then
        return true
      else
        log't is empty and empty tables are not lists'
        return false
      end
    end
  end

  do
    local keys = module.keys(t)
    -- `module.keys` returns a proper list, so if its length is not the same as the length of the table,
    -- this cannot be a list.
    if #keys ~= #t then
      log't length different from number of keys'
      return false
    end

    -- `table.sort` leverages the < comparator; it's possible to implement this on an object's metatable,
    -- but regardless, if the keys can't be sorted, we know the table cannot possibly be composed of a
    -- numerical sequence of key-value pairs, and thus is not a list.
    if not pcall(table.sort, keys) then
      log't keys unsortable'
      return false
    end
    -- NOTE(dabrady): I really wish `table.sort` didn't sort in-place. Remind me to re-implement it.
    -- Aliasing here is purely for readability.
    local sortedKeys = keys

    -- If the key with the largest value in a non-empty table is not equal to the 'length' of the table,
    -- then the length operator is inaccurate and therefore the table cannot be a list.
    if sortedKeys[#sortedKeys] ~= #t then
      log't length is inaccurate'
      return false
    end

    -- In a sequential iteration over a sorted numeric set, the value in the set corresponding to the
    -- iteration index will equal the iteration index for all indices IFF the sorted numeric set is sequential
    for i=1, #sortedKeys do
      local key = sortedKeys[i]

      -- This type-check covers custom implementations the `__lt` metatable event, which makes non-numbers
      -- compatible with `table.sort`, and wouldn't have been caught by our use of `pcall` earlier.
      -- if type(key) ~= 'number' then
      --   return false
      -- end

      -- If our iteration sequence does not match the sorted key sequence, the key sequence has gaps and
      -- therefore the original table cannot be a list.
      if i ~= key then
        log't is sparse'
        return false
      end
    end
  end

  -- Congratulations, you've won!
  return true
end

-- Returns the indices of the given object in the given table-or-list.
function module.locate(t, obj)
  -- Empty tables contain nothing, not even nil.
  if module.isEmpty(t) then
    return {}
  end

  -- Check if the given object is in the set of values in our source table
  -- local val_index = module.inverse(t, false) -- Don't reconcile collisions, we only care about presence, not value.
  local val_index = module.inverse(t, true)

  local indices = val_index[obj]
  -- NOTE(dabrady) This is my attempt at always returning a list of indices.
  -- However, it is flawed, in that it will be confused if the target object is _actually_ indexed by a table.
  -- TODO(dabrady) Is there an improvement that can be made to `inverse` that allows me to tell the difference?
  if type(indices) == 'table' then
    return indices
  else
    return {indices}
  end
end

function module.locate_similar(t, obj)
  -- Empty tables contain nothing, not even nil.
  if module.isEmpty(t) then
    return {}
  end

  local obj_type = type(obj)
  local indices = {}
  for k,v in pairs(t) do
    local v_type = type(v)
    -- Can't be similar if they're not the same type
    if v_type ~= obj_type then
      goto continue
    end

    if (v == obj) or (v_type == "table" and module.basically_the_same(v, obj)) then
      indices[#indices + 1] = k
    end

    ::continue::
  end

  return indices
end

-- Returns true if the given table-or-list contains the given object in its index.
function module.contains(t, obj)
  return not module.isEmpty(module.locate(t, obj))
end

-- Flushes all occurrences of the given values from the source table.
function module.flush(source, values, deep)
  -- Clone the source table to avoid a mutation
  local result
  if deep then
    result = module.deepCopy(source)
  else
    result = module.copy(source)
  end

  -- NOTE(dabrady) Using a value index directly instead of `module.contains` for loop efficiency
  local val_index = module.inverse(result)

  -- Remove the target items from our copy of the source table
  for i = #values, 1, -1 do
    if val_index[values[i]] then
      local locations = module.locate(result, values[i])

      for _,i in ipairs(locations) do
        -- NOTE(dabrady) Trying `table.remove` first, so as to avoid creating a 'sparse' list
        -- in the case where the source table is a list.
        -- If it fails, it is because the source table is not a 'proper' list, and will throw an error;
        -- in that case, we are free to simply remove the entry from the table Lua-style.
        if not pcall(table.remove, result, i) then
          result[i] = nil
        end
      end
    end
  end

  return result
end

-- Checks two tables for one level of sameness: are all the keys the same, and are all the
-- corresponding values the same?
function module.basically_the_same(t1, t2)
  assert(type(t1) == "table" and type(t2) == "table")

  -- NOTE(dabrady) If the two tables are lists and have the same length,
  -- we could short-circuit one of these loops. But determining whether
  -- they are lists is more expensive than just doing the two loops here.

  -- If any value of t2 is not in the values of t1, they're different.
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or v1 ~= v2 then
      return false
    end
  end

  -- If any value of t1 is not in the values of t2, they're different.
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or v1 ~= v2 then
      return false
    end
  end

  return true
end

-----------
return module
