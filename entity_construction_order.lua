local cmdefines = require("__conman__/defines.lua")
--local inv_index = cmdefines.inv_index
--local arithop = cmdefines.arithop
--local deciderop = cmdefines.deciderop
--local specials = cmdefines.specials
local knownsignals = require("knownsignals")
local signal_util = require("signal_util")
local get_signal_from_set = signal_util.get_signal_from_set
--local get_signals_filtered = signal_util.get_signals_filtered

local signal_concepts = require("signal_concepts")
--local ReadPosition = signal_concepts.ReadPosition
local ReadColor = signal_concepts.ReadColor
--local ReadBoundingBox = signal_concepts.ReadBoundingBox
local ReadFilters = signal_concepts.ReadFilters
local ReadInventoryFilters = signal_concepts.ReadInventoryFilters
local ReadItems = signal_concepts.ReadItems
--local ReadSignalList = signal_concepts.ReadSignalList

--local ReadWrite = require("ReadWrite")


local splitterside = { "left", "right", }

---@param createorder LuaSurface.create_entity_param
---@param entproto LuaEntityPrototype
---@param signals1 Signal[]
---@param signals2 Signal[]
local function nocc2(createorder,entproto,signals1,signals2)
  createorder.usecc2items=false
end
return {
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["assembling-machine"] = function(createorder,entproto,signals1,signals2)
    --set recipe if recipeid lib available
    if remote.interfaces['recipeid'] then
      createorder.recipe = remote.call('recipeid','map_recipe', get_signal_from_set(knownsignals.R,signals1))
    end
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["rocket-silo"] = function(createorder,entproto,signals1,signals2)
    createorder.auto_launch = get_signal_from_set(knownsignals.A,signals1) == 1
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["logistic-container"] = function(createorder,entproto,signals1,signals2)
    if entproto.logistic_mode == "buffer" or entproto.logistic_mode == "storage" then
      createorder.request_filters = ReadFilters(signals2, entproto.filter_count)
      createorder.usecc2items=false
    elseif entproto.logistic_mode == "requester" then
      createorder.request_filters = ReadFilters(signals2, entproto.filter_count)
      createorder.usecc2items=false
      createorder.request_from_buffers = get_signal_from_set(knownsignals.R,signals1) ~= 0
    end
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["splitter"] = function(createorder,entproto,signals1,signals2)
    createorder.input_priority = splitterside[get_signal_from_set(knownsignals.I,signals1)] or "none"
    createorder.output_priority = splitterside[get_signal_from_set(knownsignals.O,signals1)] or "none"

    createorder.filter = next(ReadItems(signals2,1))
    createorder.usecc2items=false
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["underground-belt"] = function(createorder,entproto,signals1,signals2)
    if get_signal_from_set(knownsignals.U,signals1) ~= 0 then 
      createorder.type = "output"
    else
      createorder.type = "input"
    end
    createorder.usecc2items=false
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["loader"] = function(createorder,entproto,signals1,signals2)
    if get_signal_from_set(knownsignals.U,signals1) ~= 0 then 
      createorder.type = "output"
    else
      createorder.type = "input"
    end
    createorder.filters = ReadFilters(signals2,entproto.filter_count)
    createorder.usecc2items=false
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["train-stop"] = function(createorder,entproto,signals1,signals2)
    createorder.usecc2items=false
    local a = get_signal_from_set(knownsignals.white,signals1)
    if a > 0 and a <= 255 then
      createorder.color = ReadColor(signals1)
      createorder.color.a = a
    end
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["locomotive"] = function(createorder,entproto,signals1,signals2)
    local a = get_signal_from_set(knownsignals.white,signals1)
    if a > 0 and a <= 255 then
      createorder.color = ReadColor(signals1)
      createorder.color.a = a
    end
    createorder.orientation = math.min(math.max(get_signal_from_set(knownsignals.O,signals1), 0), 65535)/65535
  end,
  ---@param createorder LuaSurface.create_entity_param
  ---@param entproto LuaEntityPrototype
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ["cargo-wagon"] = function(createorder,entproto,signals1,signals2)
    createorder.inventory = {
      bar = createorder.bar,
      filters = ReadInventoryFilters(signals2, entproto.get_inventory_size(defines.inventory.cargo_wagon))
    }
    createorder.orientation = math.min(math.max(get_signal_from_set(knownsignals.O,signals1), 0), 65535)/65535
    createorder.bar = nil
    local a = get_signal_from_set(knownsignals.white,signals1)
    if a > 0 and a <= 255 then
      createorder.color = ReadColor(signals1)
      createorder.color.a = a
    end
    createorder.usecc2items=false
  end,
  ["offshore-pump"] = nocc2,
  ["pump"] = nocc2,
  ["miner"] = nocc2,
  ["inserter"] = nocc2,
  ["curved-rail"] = nocc2,
  ["straight-rail"] = nocc2,
  ["rail-signal"] = nocc2,
  ["rail-chain-signal"] = nocc2,
  ["wall"] = nocc2,
  ["transport-belt"] = nocc2,
  ["lamp"] = nocc2,
  ["programmable-speaker"] = nocc2,
  ["power-switch"] = nocc2,
  ["roboport"] = nocc2,
  ["accumulator"] = nocc2,
  ["constant-combinator"] = nocc2,
  ["arithmetic-combinator"] = nocc2,
  ["decider-combinator"] = nocc2,
}