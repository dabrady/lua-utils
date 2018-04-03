-- Just in case someone decides to replace the builtin `require` with `loadmodule`,
-- this prevents us from losing access to it.
_G.lua_require = _G.require

local function _requireWithArgs(modName, ...)
  -- If args are provided, avoid the cache and load the
  -- module fresh with the new args.
  -- NOTE Either approach is error prone, I'm taking this one consciously.
  if not ... then
    if package.loaded[modName] then
      return package.loaded[modName]
    end
  end

  local loader, pathToMod
  local pathsChecked = ''
  for _,searcher in ipairs(package.searchers) do
    -- Each searcher returns two values, both of which may be nil:
    --   1 - either a loader function for the module in question, or a formatted string of the paths checked
    --   2 - if (1) is a loader function, this will be the path to file it will load, otherwise it will be nil
    loader, pathToMod = searcher(modName)
    if type(loader) == 'function' then
      break
    elseif type(loader) == 'string' then
      pathsChecked = pathsChecked..loader
    end
  end

  assert(type(loader) == 'function',
    string.format("module '%s' not found:%s", modName, pathsChecked))

  package.loaded[modName] = loader(modName, pathToMod, ...) or true
  return package.loaded[modName]
end

-------
return function(modName, ...)
  -- Packing into a table and counting to avoid missing explicit `nil`s.
  local args = table.pack(...)
  if #args > 0 then
    return _requireWithArgs(modName, ...)
  else
    return _G.lua_require(modName)
  end
end
