local _,_,module = ...
module = module or {}
assert(type(module) == 'table', 'must provide a table to extend')

local tell = require('lua-utils/hammerspoon/application').tell

module.tell = function(...)
  tell('Spotify', ...)
end

-----------
return module
