-- Provide the ability to encapsulate the extensions into a different table.
local _,_,module = ...
module = module or require('hs.chooser')
assert(type(module) == 'table', 'must provide a table to extend')

-- Takes a list of strings and creates a choice table formatted such that
-- it is acceptable by hs.chooser:choices
function module.generateChoiceTable(list)
  if list == nil or #list == 0 then
    return {}
  end

  local choiceTable = {}
  for _,item in ipairs(list) do
    table.insert(choiceTable, { text = item..'' })
  end

  return choiceTable
end

-----------
return module
