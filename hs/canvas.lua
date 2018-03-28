-- Provide the ability to encapsulate the extensions into a different table.
local _,_,module = ...
module = module or require('hs.canvas')
assert(type(module) == 'table', 'must provide a table to extend')

require('hs.timer')
requrie('hs.fnutils')

---- Rolling my own 'show and hide with fade-out': need to be able to cancel the animation.
module.flashable = {}
function module.flashable.new(canvasObj, options)
  options = options or {}
  local _fade -- Forward declaration for closure
  local fader = hs.timer.delayed.new(options.fadeSpeed or 0.07, function() _fade() end)
  local hider = hs.timer.delayed.new(options.showDuration or 1, hs.fnutils.partial(fader.start, fader))

  -- A sentinel representing the exit condition for our background 'fader'
  local cancelFade = false

  local function _abortFade()
    -- Set the exit condition for any ongoing fade
    cancelFade = true
    -- Cancel any ongoing fade timer
    fader:stop()
    -- Reset canvas to maximum visibility
    canvasObj:alpha(1.0)
  end

  _fade = function()
    local exit = cancelFade or (canvasObj:alpha() == 0)
    if exit then
      canvasObj:hide()
      _abortFade()
    else
      local lowerAlpha = canvasObj:alpha() - 0.1
      canvasObj:alpha(lowerAlpha)

      -- Go around again
      fader:start()
    end
  end

  local function _hideCanvas()
    cancelFade = false
    hider:start()
  end

  return {
    canvas = canvasObj,
    flash = function()
      -- Show the canvas if it's not already visible, then hide it according to configuration.
      _abortFade()
      canvasObj:show()
      _hideCanvas()
    end
  }
end

setmetatable(module.flashable, {__call = function(_, ...) return module.flashable.new(...) end})

-----------
return module
