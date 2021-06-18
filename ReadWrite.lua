
local knownsignals = require("knownsignals")
local signal_util = require("signal_util")
local get_signal_from_set = signal_util.get_signal_from_set

---@param Report function
---@param Update function
---@return fun(manager:ConManManager,signals1:Signal[],signals2:Signal[])
local function ReadWrite(Report,Update)
  return function(manager,signals1,signals2)
    local write = get_signal_from_set(knownsignals.W,signals1)
    if write == 1 then
      return Update(manager,signals1,signals2)
    else
      return Report(manager,signals1,signals2)
    end
  end
end

return ReadWrite