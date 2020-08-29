local _,_,module = ...
module = module or {}
assert(type(module) == 'table', 'must provide a table to extend')
-----------

-- NOTE(dabrady) The 'checks' package sets some globals. I don't want that
-- if I can avoid it, so if it hasn't already been loaded, I'm going to
-- prevent it by encapsulating them and then unsetting the globals immediately.
-- But if it has already been loaded, I don't want to mess with them: they
-- could be being used by others.
-- @see https://luarocks.org/modules/luarocks/
do
  local checks_already_loaded = package.loaded.checks
  require('checks')

  -- @see https://github.com/SierraWireless/luasched/blob/99e025548d772710439a28d487276cbdb5d4ccd7/c/checks.c#L291-L294
  module.__checks__ = checks
  module.__checkers__ = checkers

  if not checks_already_loaded then
    checks = nil
    checkers = nil
  end
end

-- Provide less magical type assertion.
function module.assert_type(val, t)
  module.__checks__(t) -- Asserts against the first argument to `assert_type`
  return val
end

-----------
return module
