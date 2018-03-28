-- Provide the ability to encapsulate the extensions into a different table.
local _,_,module = ...
module = module  or require('hs.application')
assert(type(module) == 'table', 'must provide a table to extend')

require('hs.applescript')
require('hs.task')

function module.tell(application, message)
  if message == nil then return nil end
  if application == nil then return nil end

  local function _tellMessage(app)
    if app == nil then
      -- print("Something's wrong: application could not be found!")
      return nil
    end

    -- print("App is running! Commanding it to do things.")

    local ok, _ = hs.applescript('tell application "'..app:name()..'" to '..message)
    if ok then
      return app
    else
      return nil
    end
  end

  if type(application) == 'userdata' then return _tellMessage(application) end
  if type(application) == 'string' then
    -- print('Converting app string')

    local app = hs.application.get(application)
    if app == nil then
      -- print("App not running: attempting to start it in the background")

      local function _tellOnOpen()
        local function sleep(n)
          local t0 = os.clock()
          while os.clock() - t0 <= n do end
        end
        app = hs.application.get(application)
        sleep(1)
        -- print('Opened! Commanding application to do things')
        _tellMessage(app)
      end

      -- Launch the application in the background and wait a reasonable amount of time
      -- for it to become responsive before telling it anything.
      hs.task.new('/usr/bin/open', _tellOnOpen, function() end, {'-ga', application}):start():waitUntilExit()

      return app
    else
      return _tellMessage(app)
    end
  end
end

-----------
return module
