local inv_index = require("__conman__/defines.lua").inv_index

---@class ConManManager
---@field ent LuaEntity
---@field surface LuaSurface
---@field force LuaForce
---@field cc1 LuaEntity
---@field cc2 LuaEntity
---@field clearcc2 boolean|nil
---@field morecc2 table<number,ConstantCombinatorParameters[]>|nil
---@field preloadstring string|nil
---@field active_book LuaItemStack|nil
---@field relative boolean
---@field schedule TrainScheduleRecord[]|nil



---@param signal SignalID
---@param set Signal[]
---@return number
local function get_signal_from_set(signal,set)
  for _,sig in pairs(set) do
    if sig.signal.type == signal.type and sig.signal.name == signal.name then
      return sig.count
    end
  end
  return 0
end

---@generic T
---@param filters table<T,SignalID>
---@param signals Signal[]
---@return table<T,number>
local function get_signals_filtered(filters,signals)
  local results = {}
  local count = 0
  for _,sig in pairs(signals) do
    for i,f in pairs(filters) do
      if f.name and sig.signal.type == f.type and sig.signal.name == f.name then
        results[i] = sig.count
        count = count + 1
        if count == #filters then return results end
      end
    end
  end
  return results
end

-- pre-built signal tables to save loads of table/string constructions
local knownsignals = require("knownsignals")

local signalsets = {
  position1 = {
    x = knownsignals.X,
    y = knownsignals.Y,
  },
  position2 = {
    x = knownsignals.U,
    y = knownsignals.V,
  },
  color = {
    r = knownsignals.red,
    g = knownsignals.green,
    b = knownsignals.blue,
  }
}


---@param signals Signal[]
---@param secondary? boolean
---@param offset? Position
---@return Position
local function ReadPosition(signals,secondary,offset)
  local set = secondary and signalsets.position2 or signalsets.position1
  local p = get_signals_filtered(set,signals)
  local x,y = (p.x or 0),(p.y or 0)
  if offset then
    x = x+offset.x
    y = y+offset.y
  end
  p.x = x
  p.y = y
  return p
end

---@param signals Signal[]
---@return Color
local function ReadColor(signals)
  local color = get_signals_filtered(signalsets.color,signals)
  color.r =  math.min(math.max(color.r, 0), 255)
  color.g =  math.min(math.max(color.g, 0), 255)
  color.b =  math.min(math.max(color.b, 0), 255)
  return color
end

---@param signals Signal[]
---@return BoundingBox
local function ReadBoundingBox(signals)
  -- adjust offests to make *inclusive* selection
  return {ReadPosition(signals,false,{x=0,y=0}),ReadPosition(signals,true,{x=1,y=1})}
end


---@param signals Signal[]
---@param count? number
---@return LogisticFilter[]
local function ReadFilters(signals,count)
  local filters = {}
  if signals then
    for i,s in pairs(signals) do
      if s.signal.type == "item" then
        filters[#filters+1]={index = #filters+1, name = s.signal.name, count = s.count}
        if count and #filters==count then break end
      end
    end
  end
  return filters
end

---@param signals Signal[]
---@param count? number
---@return InventoryFilter[]
local function ReadInventoryFilters(signals,count)
  local filters = {}
  local nfilters = 0
  if signals then
    for _,s in pairs(signals) do
      if s.signal.type == "item" then
        for b=0,31 do
          local bit = bit32.extract(s.count,b)
          if bit == 1 and not filters[b+1] then
            filters[b+1]={index = b+1, name = s.signal.name}
            nfilters = nfilters +1
            if b == 31 and count > 31 then
              for n=32,count do
                filters[n]={index = n, name = s.signal.name}
                nfilters = nfilters +1
              end
            end
          end
        end
      end
    end
  end
  return filters
end

---@param signals Signal[]
---@param count? number
---@return table<string,number>
local function ReadItems(signals,count)
  local items = {}
  if signals then
    for i,s in pairs(signals) do
      if s.signal.type == "item" then
        local n = s.count
        if n < 0 then n = n + 0x100000000 end
        items[s.signal.name] = n
        if count and #items==count then break end
      end
    end
  end
  return items
end

--TODO use iconstrip reader from magiclamp


---@param signals Signal[]
---@param nbits? number
---@return SignalID[]
local function ReadSignalList(signals,nbits)
  local selected = {}
  for i=0,(nbits or 31) do
    for _,sig in pairs(signals) do
      local sigbit = bit32.extract(sig.count,i)
      if sigbit==1 then
        selected[i+1] = sig.signal
        break
      end
    end
  end
  return selected
end

local arithop = { "*", "/", "+", "-", "%", "^", "<<", ">>", "AND", "OR", "XOR" }
local deciderop = { "<", ">", "=", "≥", "≤", "≠" }
local specials = {
  each  = {name="signal-each",       type="virtual"},
  any   = {name="signal-anything",   type="virtual"},
  every = {name="signal-everything", type="virtual"},
}

local splitterside = { "left", "right", }

---@param createorder LuaSurface.create_entity_param
---@param entproto LuaEntityPrototype
---@param signals1 Signal[]
---@param signals2 Signal[]
local function nocc2(createorder,entproto,signals1,signals2)
  createorder.usecc2items=false
end
local ConstructionOrderEntitySpecific =
{
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

---@param ghost LuaEntity
---@param control LuaGenericOnOffControlBehavior
---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
---@param forblueprint? boolean
---@return SignalID[]
local function ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)
  local siglist = {}
  if signals2 then
    siglist = ReadSignalList(signals2)
  end
  local sigmode = get_signal_from_set(knownsignals.S,signals1)
  if sigmode == 3 or sigmode == 4 then
    siglist[1] = specials.any
  elseif sigmode == 5 or sigmode == 6 then
    siglist[1] = specials.every
  end

  if forblueprint then
    control.circuit_condition={
      first_signal = siglist[1],
      second_signal = siglist[2],
      constant = get_signal_from_set(knownsignals.K,signals1),
      comparator =  deciderop[get_signal_from_set(knownsignals.O,signals1)] or "<",
      }
    control.condition = control.circuit_condition
  else
    control.circuit_condition={ condition = {
      first_signal = siglist[1],
      second_signal = siglist[2],
      constant = get_signal_from_set(knownsignals.K,signals1),
      comparator =  deciderop[get_signal_from_set(knownsignals.O,signals1)] or "<",
      }}
  end
  -- for more complex controls to read additional signals
  return siglist
end

local ConstructionOrderControlBehavior =
{
  ---@param ghost LuaEntity
  ---@param control LuaConstantCombinatorControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.constant_combinator] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local filters = {}
    if signals2 then
      for i,s in pairs(signals2) do
        filters[#filters+1]={index = #filters+1, count = s.count, signal = s.signal}
      end
    end
    if forblueprint then 
      control.filters=filters 
      control.is_on = get_signal_from_set(knownsignals.O,signals1) == 0
    else
      control.parameters=filters
      control.enabled = get_signal_from_set(knownsignals.O,signals1) == 0
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaArithmeticCombinatorControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.arithmetic_combinator] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end
    local sigmode = get_signal_from_set(knownsignals.S,signals1)
    if sigmode == 1 then
      siglist[1] = specials.each
    elseif sigmode == 2 then
      siglist[1] = specials.each
      siglist[3] = specials.each
    elseif sigmode == 8 then
      siglist[2] = specials.each
    elseif sigmode == 9 then
      siglist[2] = specials.each
      siglist[3] = specials.each
    end

    local config = {
      first_signal = siglist[1],
      second_signal = siglist[2],
      first_constant = get_signal_from_set(knownsignals.J,signals1),
      second_constant = get_signal_from_set(knownsignals.K,signals1),
      operation = arithop[get_signal_from_set(knownsignals.O,signals1)] or "*",
      output_signal = siglist[3],
      }
    if forblueprint then
      control.arithmetic_conditions=config
    else
      control.parameters=config
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaDeciderCombinatorControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.decider_combinator] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end
    local sigmode = get_signal_from_set(knownsignals.S,signals1)
    if sigmode == 1 then
      siglist[1] = specials.each
    elseif sigmode == 2 then
      siglist[1] = specials.each
      siglist[3] = specials.each
    elseif sigmode == 3 then
      siglist[1] = specials.any
    elseif sigmode == 4 then
      siglist[1] = specials.any
      siglist[3] = specials.every
    elseif sigmode == 5 then
      siglist[1] = specials.every
    elseif sigmode == 6 then
      siglist[1] = specials.every
      siglist[3] = specials.every
    elseif sigmode == 7 then
      siglist[3] = specials.every
    end

    local config = {
      first_signal = siglist[1],
      second_signal = siglist[2],
      constant = get_signal_from_set(knownsignals.K,signals1),
      comparator =  deciderop[get_signal_from_set(knownsignals.O,signals1)] or "<",
      output_signal = siglist[3],
      copy_count_from_input = get_signal_from_set(knownsignals.F,signals1) == 0,
      }
    if forblueprint then
      control.decider_conditions = config
    else
      control.parameters=config
    end
  end,
  [defines.control_behavior.type.generic_on_off] = ReadGenericOnOffControl,
  ---@param ghost LuaEntity
  ---@param control LuaMiningDrillControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.mining_drill] = function(ghost,control,manager,signals1,signals2,forblueprint)
    ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)

    control.circuit_enable_disable = get_signal_from_set(knownsignals.E,signals1) ~= 0
    local r = get_signal_from_set(knownsignals.R,signals1)
    if r == 1 then 
      control.circuit_read_resources = true
      control.resource_read_mode = defines.control_behavior.mining_drill.resource_read_mode.this_miner
    elseif r == 2 then
      control.circuit_read_resources = true
      control.resource_read_mode = defines.control_behavior.mining_drill.resource_read_mode.entire_patch
    else 
      control.circuit_read_resources = false
    end
    if forblueprint then
      control.circuit_resource_read_mode = control.resource_read_mode
      control.resource_read_mode = nil
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaTrainStopControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.train_stop] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

    if forblueprint then
      control.circuit_enable_disable = get_signal_from_set(knownsignals.E,signals1) ~= 0
    else  
      control.enable_disable = get_signal_from_set(knownsignals.E,signals1) ~= 0
    end
    control.read_from_train = get_signal_from_set(knownsignals.R,signals1) ~= 0
    control.send_to_train = get_signal_from_set(knownsignals.T,signals1) ~= 0

    if siglist[3] then
      if forblueprint then
        control.train_stopped_signal = siglist[3]
      else
        control.stopped_train_signal = siglist[3]
      end
      control.read_stopped_train = true
    else
      control.read_stopped_train = false
    end

    -- this really should be in entity-type handling, but it's easier here
    if manager.preloadstring then 
      if forblueprint then
        ghost.station = manager.preloadstring
      else
        ghost.backer_name = manager.preloadstring
      end
      manager.preloadstring = nil
      manager.preloadcolor = nil
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaInserterControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.inserter] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)

    if get_signal_from_set(knownsignals.B,signals1) ~= 0 then 
      if forblueprint then 
        ghost.filter_mode = "blacklist"
      else
        ghost.inserter_filter_mode = "blacklist"
      end
    else
      if forblueprint then 
        ghost.filter_mode = "whitelist"
      else
        ghost.inserter_filter_mode = "whitelist"
      end
    end

    if get_signal_from_set(knownsignals.E,signals1) ~= 0 then 
      control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable
    elseif get_signal_from_set(knownsignals.F,signals1) ~= 0 then
      control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.set_filters
    else
      control.circuit_mode_of_operation = defines.control_behavior.inserter.circuit_mode_of_operation.none
    end
    
    local sig_i = get_signal_from_set(knownsignals.I,signals1)
    if sig_i then
      if forblueprint then 
        ghost.override_stack_size = sig_i
      else
        ghost.inserter_stack_size_override = sig_i
      end
    end

    local r = get_signal_from_set(knownsignals.R,signals1)
    if r == 1 then 
      control.circuit_read_hand_contents = true
      control.circuit_hand_read_mode = defines.control_behavior.inserter.hand_read_mode.pulse
    elseif r == 2 then
      control.circuit_read_hand_contents = true
      control.circuit_hand_read_mode = defines.control_behavior.inserter.hand_read_mode.hold
    else 
      control.circuit_read_hand_contents = false
    end

    if siglist[3] then 
      control.circuit_set_stack_size = true
      if forblueprint then
        control.stack_control_input_signal = siglist[3]
      else  
        control.circuit_stack_control_signal = siglist[3]
      end
    end

    for i=1,ghost.ghost_prototype.filter_count do 
      if siglist[i+3] and siglist[i+3].type == "item" then 
        ghost.set_filter(i, siglist[i+3].name)
      else
        ghost.set_filter(i, nil)
      end
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaLampControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.lamp] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)
    control.use_colors = get_signal_from_set(knownsignals.C,signals1) ~= 0
  end,
  ---@param ghost LuaEntity
  ---@param control LuaLogisticContainerControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  [defines.control_behavior.type.logistic_container] = function(ghost,control,manager,signals1,signals2)
    if ghost.ghost_prototype.logistic_mode == "requester" or ghost.ghost_prototype.logistic_mode == "buffer" then
      if get_signal_from_set(knownsignals.S,signals1) ~= 0 then 
        control.circuit_mode_of_operation = defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests
      end
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaRoboportControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.roboport] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end

    control.read_logistics = get_signal_from_set(knownsignals.L,signals1) ~= 0
    control.read_robot_stats = get_signal_from_set(knownsignals.R,signals1) ~= 0

    control.available_logistic_output_signal = siglist[1]
    control.total_logistic_output_signal = siglist[2]
    control.available_construction_output_signal = siglist[3]
    control.total_construction_output_signal = siglist[4]
  end,
  ---@param ghost LuaEntity
  ---@param control LuaTransportBeltControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.transport_belt] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)
    control.enable_disable = get_signal_from_set(knownsignals.E,signals1) ~= 0

    local r = get_signal_from_set(knownsignals.R,signals1)
    if r == 1 then 
      control.read_contents = true
      control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.pulse
    elseif r == 2 then
      control.read_contents = true
      control.read_contents_mode = defines.control_behavior.transport_belt.content_read_mode.hold
    else 
      control.read_contents = false
    end
    if forblueprint then
      control.circuit_enable_disable = control.enable_disable
      control.circuit_read_hand_contents = control.read_contents
      control.circuit_contents_read_mode = control.read_contents_mode
      control.enable_disable = nil
      control.read_contents = nil
      control.read_contents_mode = nil
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaAccumulatorControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  [defines.control_behavior.type.accumulator] = function(ghost,control,manager,signals1,signals2)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end
    
    control.output_signal = siglist[1]
  end,
  ---@param ghost LuaEntity
  ---@param control LuaRailSignalControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.rail_signal] = function(ghost,control,manager,signals1,signals2,forblueprint)
    -- Rail doesn't actually inheret from Generic, but it's close enough to work
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)

    if forblueprint then
      control.circuit_close_signal = get_signal_from_set(knownsignals.E,signals1) ~= 0
      control.circuit_read_signal = get_signal_from_set(knownsignals.R,signals1) ~= 0
      control.red_output_signal = siglist[3]
      control.orange_output_signal = siglist[4]
      control.green_output_signal = siglist[5]
    else
      control.close_signal = get_signal_from_set(knownsignals.E,signals1) ~= 0
      control.read_signal = get_signal_from_set(knownsignals.R,signals1) ~= 0
      control.red_signal = siglist[3]
      control.orange_signal = siglist[4]
      control.green_signal = siglist[5]
    end
  end,
  ---@param ghost LuaEntity
  ---@param control LuaRailChainSignalControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.rail_chain_signal] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end
    
    if forblueprint then
      control.red_output_signal = siglist[3]
      control.orange_output_signal = siglist[4]
      control.green_output_signal = siglist[5]
      control.blue_output_signal = siglist[6]
    else
      control.red_signal = siglist[3]
      control.orange_signal = siglist[4]
      control.green_signal = siglist[5]
      control.blue_signal = siglist[6]
    end
  end,
  
  ---@param ghost LuaEntity
  ---@param control LuaWallControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.wall] = function(ghost,control,manager,signals1,signals2,forblueprint)
    -- Wall doesn't actually inheret from Generic, but it's close enough to work
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)

    if forblueprint then
      control.circuit_open_gate = get_signal_from_set(knownsignals.E,signals1) ~= 0
      control.circuit_read_sensor = get_signal_from_set(knownsignals.R,signals1) ~= 0
    else
      control.open_gate = get_signal_from_set(knownsignals.E,signals1) ~= 0
      control.read_sensor = get_signal_from_set(knownsignals.R,signals1) ~= 0
    end
    
    control.output_signal = siglist[3]
  end,
  ---@param ghost LuaEntity
  ---@param control LuaProgrammableSpeakerControlBehavior
  ---@param manager ConManManager
  ---@param signals1 Signal[]
  ---@param signals2 Signal[]
  ---@param forblueprint? boolean
  [defines.control_behavior.type.programmable_speaker] = function(ghost,control,manager,signals1,signals2,forblueprint)
    -- Speaker doesn't actually inheret from Generic, but it's close enough to work
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2,forblueprint)

    local volume = (get_signal_from_set(knownsignals.U,signals1) or 100)/100
    
    ghost.parameters = {
      playback_volume = volume,
      playback_globally = get_signal_from_set(knownsignals.G,signals1) ~= 0,
      allow_polyphony = get_signal_from_set(knownsignals.P,signals1) ~= 0,
    }
    ghost.alert_parameters = {
      show_alert = get_signal_from_set(knownsignals.A,signals1) ~= 0,
      show_on_map = get_signal_from_set(knownsignals.M,signals1) ~= 0,
      icon_signal_id = siglist[3],
      alert_message = manager.preloadstring,
    }
    manager.preloadstring = nil
    manager.preloadcolor = nil
    control.circuit_parameters = {
      signal_value_is_pitch = get_signal_from_set(knownsignals.V,signals1) ~= 0,
      instrument_id = get_signal_from_set(knownsignals.I,signals1) or 1,
      note_id = get_signal_from_set(knownsignals.J,signals1) or 1,
    }
  end,
}

local EntityTypeToControlBehavior = 
{
  ["accumulator"] = defines.control_behavior.type.accumulator,
  ["arithmetic-combinator"] = defines.control_behavior.type.arithmetic_combinator,
  ["constant-combinator"] = defines.control_behavior.type.constant_combinator,
  ["container"] = defines.control_behavior.type.container,
  ["decider-combinator"] = defines.control_behavior.type.decider_combinator,
  ["inserter"] = defines.control_behavior.type.inserter,
  ["lamp"] = defines.control_behavior.type.lamp,
  ["logistic-container"] = defines.control_behavior.type.logistic_container,
  ["mining-drill"] = defines.control_behavior.type.mining_drill,
  ["programmable-speaker"] = defines.control_behavior.type.programmable_speaker,
  ["rail-chain-signal"] = defines.control_behavior.type.rail_chain_signal,
  ["rail-signal"] = defines.control_behavior.type.rail_signal,
  ["roboport"] = defines.control_behavior.type.roboport,
  ["storage-tank"] = defines.control_behavior.type.storage_tank,
  ["train-stop"] = defines.control_behavior.type.train_stop,
  ["transport-belt"] = defines.control_behavior.type.transport_belt,
  ["wall"] = defines.control_behavior.type.wall,

  ["offshore-pump"] = defines.control_behavior.type.generic_on_off,
  ["power-switch"] = defines.control_behavior.type.generic_on_off,
  ["pump"] = defines.control_behavior.type.generic_on_off,
}

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
---@param forblueprint? boolean
---@return BlueprintEntity|nil
local function ConstructionOrder(manager,signals1,signals2,forblueprint)
  local createorder = {
    name='entity-ghost',
    position = ReadPosition(signals1),
    force = manager.ent.force,
    expires = false,
    direction = get_signal_from_set(knownsignals.D,signals1),
    usecc2items = not forblueprint,
  }

  -- only set bar if it's non-zero, else chests are disabled by default.
  local bar = get_signal_from_set(knownsignals.B,signals1)
  if bar > 0 then createorder.bar = bar end

  for _,signal in pairs(signals1) do
    if signal.signal.type == "item" and signal.signal.name ~= "construction-robot" then
      local itemproto = game.item_prototypes[signal.signal.name]
      local entproto = itemproto.place_result
      local tileresult = itemproto.place_as_tile_result

      if itemproto.type == "rail-planner" then
        if signal.count == 1 then
          entproto = itemproto.straight_rail
        elseif signal.count == 2 then
          entproto = itemproto.curved_rail
        end
      end

      if entproto then
        createorder.inner_name = entproto.name
        
        -- adjust position to grid properly...
        if entproto.type == "curved-rail" then
          -- snap to evens
          createorder.position.x = createorder.position.x - (createorder.position.x%2)
          createorder.position.y = createorder.position.y - (createorder.position.y%2)
        elseif entproto.type == "straight-rail" or entproto.type == "train-stop" then
          -- snap to odds
          createorder.position.x = createorder.position.x - (createorder.position.x%2) + 1
          createorder.position.y = createorder.position.y - (createorder.position.y%2) + 1
        elseif entproto.type == "offshore-pump" then
          -- snap to tile centers
          createorder.position.x = createorder.position.x + 0.5
          createorder.position.y = createorder.position.y + 0.5
        elseif entproto.type == "locomotive" or entproto.type == "cargo-wagon" or entproto.type == "fluid-wagon" or entproto.type == "artillery-wagon" then
          -- don't bother snapping trains, you just have to get them right...
        else
          -- snap based on box size
          local box = entproto.collision_box
          local width = math.ceil(box.right_bottom.x - box.left_top.x)
          local offsetX = width % 2 / 2
          local height = math.ceil(box.right_bottom.y - box.left_top.y)
          local offsetY = height % 2 / 2
          
          if createorder.direction == 2 or createorder.direction == 6 then
            offsetX,offsetY = offsetY,offsetX
          end

          createorder.position.x = createorder.position.x + offsetX
          createorder.position.y = createorder.position.y + offsetY
        end

        local special = ConstructionOrderEntitySpecific[entproto.type]
        if special then
          special(createorder,entproto,signals1,signals2)
        end
        
        if forblueprint then
          createorder.ghost_prototype = entproto
        end

        break -- once we're found one, get out of the loop, so we don't build multiple things.
      elseif tileresult then
        createorder.name = "tile-ghost"
        createorder.inner_name = tileresult.result.name
        -- All tiles are one tile big...
        createorder.position.x = createorder.position.x + 0.5
        createorder.position.y = createorder.position.y + 0.5

        break -- once we're found one, get out of the loop, so we don't build multiple things.
      end
    end
  end

  if createorder.inner_name then
    if not forblueprint then
      local ghost =  manager.ent.surface.create_entity(createorder)
      if createorder.position.x ~= ghost.position.x or createorder.position.y ~= ghost.position.y then
        log(serpent.dump({name=createorder.inner_name,expected=createorder.position,got=ghost.position}))
      end
      if ghost and ghost.name == "entity-ghost" then
        local control = ghost.get_or_create_control_behavior()
        if control then
          local special = ConstructionOrderControlBehavior[control.type]
          if special then
            special(ghost,control,manager,signals1,signals2)
          end
        end
        if createorder.usecc2items then
          if signals2 then
            ghost.item_requests = ReadItems(signals2)
          end
        end
        script.raise_event(defines.events.script_raised_built, {entity=ghost})
      end
    elseif createorder.name == "entity-ghost" then --and forblueprint
      local controltype = EntityTypeToControlBehavior[createorder.ghost_prototype.type]
      if controltype then
        -- enough fake objects for the various control specific stuff...
        local control = { parameters = {} }
        createorder.control_behavior = control
        local filters = {}
        createorder.filters = filters
        createorder.set_filter = function(i,name)
          if name then
            for j,filter in pairs(filters) do
              if filter.index == i then
                filters[j] = {index=i,name=name}
                return
              end
            end
            filters[#filters+1] = {index=i,name=name}
          end
        end
        local special = ConstructionOrderControlBehavior[controltype]
        if special then
          special(createorder,control,manager,signals1,signals2,true)
        end
      end
      --clean up a bit, ready for a bp...
      createorder.name = createorder.inner_name
      createorder.inner_name = nil
      createorder.set_filter = nil
      return createorder
    end
  end
end

---@param manager ConManManager
local function EjectBlueprint(manager)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)[inv_index.bp]
  local outInv = manager.ent.get_inventory(defines.inventory.assembling_machine_output)[inv_index.bp]
  if inInv.valid and inInv.valid_for_read and outInv.valid and not outInv.valid_for_read then
    outInv.transfer_stack(inInv)
  end
end

---@param manager ConManManager
local function EjectBlueprintBook(manager)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)[inv_index.book]
  local outInv = manager.ent.get_inventory(defines.inventory.assembling_machine_output)[inv_index.book]
  if inInv.valid and inInv.valid_for_read and outInv.valid and not outInv.valid_for_read then
    outInv.transfer_stack(inInv)
    manager.active_book = nil
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param allow_empty? boolean
---@return LuaItemStack
local function GetActiveBook(manager,signals1,allow_empty)
  -- if this manager has an "active" book, select that, else take the book slot of input inventory
  local active_book = manager.active_book
  if active_book and active_book.valid_for_read and active_book.name == "blueprint-book" then
    return active_book
  else
    local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
    local book = inInv[inv_index.book]
    if allow_empty or book.valid_for_read then
      return book
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@return LuaItemStack
local function GetBlueprint(manager, signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local bp = inInv[inv_index.bp]
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then return bp end
  local book = GetActiveBook(manager,signals1)
  --check if there actually is a blueprint book.
  if book then
    local bookinv = book.get_inventory(defines.inventory.item_main)
    if page <= #bookinv then
      --TODO: make sure it's really a blueprint
      bp = bookinv[page]
    end
  end
  return bp
end

---@param manager ConManManager
---@param signals1 Signal[]
local function ClearOrCreateBlueprint(manager,signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then
    inInv[inv_index.bp].set_stack("blueprint")
    return
  end
  local book = GetActiveBook(manager,signals1)
  --check if there actually is a blueprint book.
  if book then
    local bookinv = book.get_inventory(defines.inventory.item_main)
    if page <= #bookinv then
      bookinv[page].set_stack("blueprint")
    elseif page == #bookinv+1 then
      bookinv.insert("blueprint")
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
local function DestroyBlueprint(manager,signals1)
  GetBlueprint(manager, signals1).clear()
end

---@param manager ConManManager
---@param signals1 Signal[]
local function ClearOrCreateBlueprintBook(manager,signals1)
  local book = GetActiveBook(manager,signals1,true)
  if book then
    book.set_stack("blueprint-book")
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
local function DestroyBlueprintBook(manager,signals1)
  local book = GetActiveBook(manager,signals1)
  if book then
    book.clear()
  end
end

---@param position Position
---@param name string
---@param direction defines.direction
---@param searchlist BlueprintEntity[]|Tile[]
local function AdjustBlueprintPosition(position,name,direction,searchlist)
  if searchlist then
    for _,ent in pairs(searchlist) do
      if ent.name == name then
        if __DebugAdapter then __DebugAdapter.print(ent) end
        -- 0 = north => x,y = x,y
        local x,y = ent.position.x,ent.position.y
        if direction == 2 then
          -- 2 = east
          x,y = -y,x
        elseif direction == 4 then
          -- 4 = south
          x,y = -x,-y
        elseif direction == 6 then
          -- 6 = west
          x,y = y,-x
        end
        position.x = position.x - x
        position.y = position.y - y
        break
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function DeployBlueprint(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read and bp.is_blueprint_setup() then

    local force_build = get_signal_from_set(knownsignals.F,signals1)==1
    local position = ReadPosition(signals1)
    local direction = math.floor(get_signal_from_set(knownsignals.D,signals1)/2)*2

    if manager.anchor then
      if not manager.anchor.valid then
        manager.anchor = nil
      else
        local bpents = bp.get_blueprint_entities()
        local name = manager.anchor.name
        AdjustBlueprintPosition(position,name,direction,bpents)
      end
    elseif manager.anchor_tile then
      if not manager.anchor_tile.valid then
        manager.anchor_tile = nil
      else
        local bptiles = bp.get_blueprint_tiles()
        local name = manager.anchor_tile.name
        AdjustBlueprintPosition(position,name,direction,bptiles)
      end
    end
    bp.build_blueprint{
      surface=manager.ent.surface,
      force=manager.ent.force,
      position=position,
      direction=direction,
      force_build=force_build,
      raise_built=true,
    }
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function CaptureBlueprint(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local capture_tiles = get_signal_from_set(knownsignals.T,signals1)==1
    local capture_entities = get_signal_from_set(knownsignals.E,signals1)==1
    bp.create_blueprint{
      surface = manager.ent.surface,
      force = manager.ent.force,
      area = ReadBoundingBox(signals1),
      always_include_tiles = capture_tiles,
    }

    if bp.is_blueprint_setup() then
      -- reset icons
      bp.blueprint_icons = bp.default_icons
    end

    if not capture_tiles and bp.get_blueprint_tiles() then 
      bp.set_blueprint_tiles(nil)
    end
    if not capture_entities and bp.get_blueprint_entities() then 
      bp.set_blueprint_entities(nil)
    end
    if signals2 then
      -- set or clear label and color from cc2
      if remote.interfaces['signalstrings'] then
        bp.label = remote.call('signalstrings','signals_to_string',signals2,true)
      else
        bp.label = ''
      end

      local a = get_signal_from_set(knownsignals.white,signals2)
      if a > 0 and a <= 255 then
        local color = ReadColor(signals2)
        color.a = a
        bp.label_color = color
      else
        bp.label_color = { r=1, g=1, b=1, a=1 }
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
---@param color defines.wire_type
---@param disconnect? boolean
local function ConnectWire(manager,signals1,signals2,color,disconnect)
  local z = get_signal_from_set(knownsignals.Z,signals1)
  if z~=2 then z=1 end

  local w = get_signal_from_set(knownsignals.W,signals1)
  if w~=2 then w=1 end

  local ent1 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signals1,false,{x=0.5,y=0.5})}[1]
  local ent2 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signals1,true,{x=0.5,y=0.5})}[1]

  if not (ent1 and ent1.valid and ent2 and ent2.valid) then return end
  
  if not color then
    if ent1.type == "electric-pole" and ent2.type == "electric-pole" then
      if disconnect then
        ent1.disconnect_neighbour(ent2)
      else
        ent1.connect_neighbour(ent2)
      end
    end
  else
    local target = {
      target_entity = ent2,
      wire = color,
      source_circuit_id = z,
      target_circuit_id = w,
    }
    if disconnect then
      ent1.disconnect_neighbour(target)
    else
      ent1.connect_neighbour(target)
    end
  end
end

---@param manager ConManManager
---@param item LuaItemStack
---@param dumping? boolean
---@return ConstantCombinatorParameters[]|nil
local function ReportLabel(manager,item,dumping)
  local outsignals = {}
  if item.label and remote.interfaces['signalstrings'] then
    -- create label signals
    outsignals = remote.call('signalstrings','string_to_signals', item.label)
  end

  -- add color signals
  if item.label_color then
    outsignals[#outsignals+1]={index=#outsignals+1,count=item.label_color.r*256,signal=knownsignals.red}
    outsignals[#outsignals+1]={index=#outsignals+1,count=item.label_color.g*256,signal=knownsignals.green}
    outsignals[#outsignals+1]={index=#outsignals+1,count=item.label_color.b*256,signal=knownsignals.blue}
    outsignals[#outsignals+1]={index=#outsignals+1,count=item.label_color.a*256,signal=knownsignals.white}
  end
  if dumping then return outsignals end
  manager.cc2.get_or_create_control_behavior().parameters=outsignals
  manager.clearcc2 = true
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintLabel(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid_for_read and bp.is_blueprint then
    ReportLabel(manager,bp)
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintBookLabel(manager,signals1,signals2)
  local book = GetActiveBook(manager,signals1)
  if book then
    ReportLabel(manager,book)
  end
end

---@param item LuaItemStack
---@param signals2 Signal[]
local function UpdateItemLabel(item,signals2)
  -- set or clear label and color from cc2
  if remote.interfaces['signalstrings'] and signals2 then
    item.label = remote.call('signalstrings','signals_to_string',signals2,true)
  else
    item.label = ''
  end
  local a = get_signal_from_set(knownsignals.white,signals2)
  if a > 0 and a <= 255 then
    local color = ReadColor(signals2)
    color.a = a
    item.label_color = color
  else
    item.label_color = { r=1, g=1, b=1, a=1 }
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintLabel(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read and bp.is_blueprint_setup() then
    UpdateItemLabel(bp,signals2)
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintBookLabel(manager,signals1,signals2)
  local book = GetActiveBook(manager,signals1)
  if book then
    UpdateItemLabel(book,signals2)
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ChangeDirBlueprintBook(manager,signals1,signals2)
  ---@type LuaItemStack
  local abook = GetActiveBook(manager,signals1)
  if abook then
    ---@type LuaInventory
    local bookInv = abook.get_inventory(defines.inventory.item_main)
    local size = #bookInv
    local index = get_signal_from_set(knownsignals.grey,signals1)
    local create = get_signal_from_set(knownsignals.grey,signals1)~=0
    if index == -1 then
      -- reset to root book
      manager.active_book = nil
    elseif index > 0 and index <= size then
      ---@type LuaItemStack
      local item = bookInv[index]
      if item.is_blueprint_book then
        manager.active_book = item
      elseif not item.valid_for_read and create then
        item.set_stack("blueprint-book")
        manager.active_book = item
      end
    elseif create and (index==size+1) and bookInv.count_empty_stacks()==0 then
      bookInv.insert("blueprint-book")
      local newsize = #bookInv
      if newsize == index then
        manager.active_book = bookInv[index]
      else
        manager.active_book = nil
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ListBlueprintBook(manager,signals1,signals2)
  ---@type LuaItemStack
  local book = GetActiveBook(manager,signals1)
  if book then
    ---@type LuaInventory
    local bookInv = book.get_inventory(defines.inventory.item_main)
    local size = #bookInv
    ---@type Signal[]
    local outsignals = {
      {index=1,count=size, signal=knownsignals.grey }
    }
    local start = get_signal_from_set(knownsignals.grey,signals1)
    if start == 0 then start = 1 end
    if start > 0 and start <=size then
      for i = 0,31,1 do
        local j = start+i
        if j > #bookInv then break end
        local item = bookInv[j]
        outsignals[#outsignals+1]={index=#outsignals+1,count=bit32.lshift(1,i),signal={type="item",name=item.name}}
      end
    end
    manager.cc2.get_or_create_control_behavior().parameters=outsignals
    manager.clearcc2 = true
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function InsertBlueprintToBook(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local bp = inInv[inv_index.bp]
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then return end
  local book = GetActiveBook(manager,signals1)
  --check if there actually is a blueprint book and a print to insert
  if bp.valid and bp.valid_for_read and book then
    local bookInv = book.get_inventory(defines.inventory.item_main)
    if page <= #bookInv then
      bookInv[page].set_stack(bp)
    elseif page == #bookInv+1 then
      bookInv.insert(bp)
    end
    bp.clear()
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function TakeBlueprintFromBook(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local bp = inInv[inv_index.bp]
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then return end
  local book = GetActiveBook(manager,signals1)
  --check if there actually is a blueprint book, and the print slot is free
  if bp.valid and not bp.valid_for_read and book then 
    local bookinv = book.get_inventory(defines.inventory.item_main)
    if page <= bookinv.get_item_count() then
      bp.transfer_stack(bookinv[page])
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintBoM(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  local outsignals = {}
  if bp.valid and bp.valid_for_read then
    -- BoM signals
    for k,v in pairs(bp.cost_to_build) do
      outsignals[#outsignals+1]={index=#outsignals+1,count=v,signal={name=k,type="item"}}
    end
    manager.cc2.get_or_create_control_behavior().parameters=outsignals
    manager.clearcc2 = true
  end
end

---@param bp LuaItemStack
---@return ConstantCombinatorParameters[]
local function ReportBlueprintIconsInternal(bp)
  local outsignals = {}
  ---@typelist number,BlueprintSignalIcon
  for _,icon in pairs(bp.blueprint_icons) do
    outsignals[#outsignals+1]={index=#outsignals+1,count=bit32.lshift(1,icon.index - 1),signal=icon.signal}
  end
  return outsignals
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintIcons(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    manager.cc2.get_or_create_control_behavior().parameters=ReportBlueprintIconsInternal(bp)
    manager.clearcc2 = true
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintIcons(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read and signals2 then
    local siglist = ReadSignalList(signals2)
    local icons = {}
    for i=1,4 do
      local sig = siglist[i]
      if sig then
        icons[#icons+1] = {index = i, signal = sig }
      end
    end
    bp.blueprint_icons = icons
  end
end

---@param tile table
---@return ConstantCombinatorParameters[]
local function ReportBlueprintTileInternal(tile)
  local outsignals = {}
  local item = game.tile_prototypes[tile.name].items_to_place_this[1]
  outsignals[1]={index=1,count=1,signal={type="item",name=item.name}}
  outsignals[2]={index=2,count=tile.position.x,signal=knownsignals.X}
  outsignals[3]={index=3,count=tile.position.y,signal=knownsignals.Y}
  return outsignals
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintTile(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local tiles = bp.get_blueprint_tiles()
    local t = get_signal_from_set(knownsignals.T,signals1)
    if t > 0 and t <= #tiles then
      local tile = tiles[t]
      manager.cc2.get_or_create_control_behavior().parameters=ReportBlueprintTileInternal(tile)
      manager.clearcc2 = true
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintTile(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local tiles = bp.get_blueprint_tiles() or {}
    local t = get_signal_from_set(knownsignals.T,signals1)
    if t > 0 and t <= #tiles+1 then
      local newtile
      for _,signal in pairs(signals1) do
        if signal.signal.type == "item" and signal.signal.name ~= "blueprint" and signal.signal.name ~= "blueprint-book" then
          local itemproto = game.item_prototypes[signal.signal.name]
          local tileresult = itemproto.place_as_tile_result
          if tileresult then
            newtile = {
              name = tileresult.result.name,
              position = ReadPosition(signals1)
            }
            break -- once we're found one, get out of the loop, so we don't build multiple things.
          end
        end
      end
      if newtile then
        tiles[t] = newtile
        bp.set_blueprint_tiles(tiles)
      end
    end
  end
end

---@param control BlueprintControlBehavior
---@param cc1 ConstantCombinatorParameters[]
---@param cc2 ConstantCombinatorParameters[]
local function ReportGenericOnOffControl(control,cc1,cc2)
  local condition = control.condition or control.circuit_condition
  if condition then
    if condition.first_signal then 
      if condition.first_signal.name == "signal-anything" then
        cc1[#cc1+1]={index=#cc1+1,count=3,signal=knownsignals.S}
      elseif condition.first_signal.name == "signal-everything" then
        cc1[#cc1+1]={index=#cc1+1,count=5,signal=knownsignals.S}
      else
        cc2[#cc2+1]={index=#cc2+1,count=1,signal=condition.first_signal}
      end
    end
    if condition.second_signal then 
      cc2[#cc2+1]={index=#cc2+1,count=2,signal=condition.second_signal}
    end
    if condition.constant then
      cc1[#cc1+1]={index=#cc1+1,count=condition.constant,signal=knownsignals.K}
    end
    if condition.comparator then
      for i,op in pairs(deciderop) do
        if condition.comparator == op then
          cc1[#cc1+1]={index=#cc1+1,count=i,signal=knownsignals.O}
          break
        end
      end
    end
  end
end
local ReportControlBehavior = {
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.constant_combinator] = function(control,cc1,cc2)
    if control.filters then 
      for _,filter in pairs(control.filters) do
        filter.index = #cc2+1
        cc2[#cc2+1]=filter
      end
    end
    if control.is_on == false then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.O}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.arithmetic_combinator] = function(control,cc1,cc2)
    local condition = control.arithmetic_conditions
    if condition then
      -- each can be first (=1) or second (=8) input, and possibly output if one of those (+1)
      local special = 0
      
      if condition.first_signal then 
        if condition.first_signal.name == "signal-each" then
          special = 1 
        else -- first signal not nil and not each
          cc2[#cc2+1]={index=#cc2+1,count=1,signal=condition.first_signal}
        end
      elseif condition.first_constant then
        cc1[#cc1+1]={index=#cc1+1,count=condition.first_constant,signal=knownsignals.J}
      end

      if condition.second_signal then 
        if condition.second_signal.name == "signal-each" then
          special = 8
        else -- second signal not nil and not each
          cc2[#cc2+1]={index=#cc2+1,count=2,signal=condition.second_signal}
        end
      elseif condition.second_constant then
        cc1[#cc1+1]={index=#cc1+1,count=condition.second_constant,signal=knownsignals.K}
      end

      if condition.output_signal then
        if special ~= 0 then
          if condition.output_signal.name == "signal-each" then
            special = special + 1
          else
            cc2[#cc2+1]={index=#cc2+1,count=4,signal=condition.output_signal}
          end
        else
          cc2[#cc2+1]={index=#cc2+1,count=4,signal=condition.output_signal}
        end
      end

      if special ~= 0 then
        cc1[#cc1+1]={index=#cc1+1,count=special,signal=knownsignals.S}
      end

      if condition.operation  then
        for i,op in pairs(arithop) do
          if condition.operation == op then
            cc1[#cc1+1]={index=#cc1+1,count=i,signal=knownsignals.O}
            break
          end
        end
      end
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.decider_combinator] = function(control,cc1,cc2)
    local condition = control.decider_conditions
    if condition then
      if condition.first_signal then 
        if condition.first_signal.name == "signal-each" then
          if condition.output_signal and condition.output_signal.name == "signal-each" then
            cc1[#cc1+1]={index=#cc1+1,count=2,signal=knownsignals.S}
          else
            cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.S}
            if condition.output_signal then
              cc2[#cc2+1]={index=#cc2+1,count=4,signal=condition.output_signal}
            end
          end
        elseif condition.first_signal.name == "signal-anything" then
          if condition.output_signal and condition.output_signal.name == "signal-everything" then
            cc1[#cc1+1]={index=#cc1+1,count=4,signal=knownsignals.S}
          else
            cc1[#cc1+1]={index=#cc1+1,count=3,signal=knownsignals.S}
            if condition.output_signal then
              cc2[#cc2+1]={index=#cc2+1,count=4,signal=condition.output_signal}
            end
          end
        elseif condition.first_signal.name == "signal-everything" then
          if condition.output_signal and condition.output_signal.name == "signal-everything" then
            cc1[#cc1+1]={index=#cc1+1,count=6,signal=knownsignals.S}
          else
            cc1[#cc1+1]={index=#cc1+1,count=5,signal=knownsignals.S}
            if condition.output_signal then
              cc2[#cc2+1]={index=#cc2+1,count=4,signal=condition.output_signal}
            end
          end
        else
          cc2[#cc2+1]={index=#cc2+1,count=1,signal=condition.first_signal}
          if condition.output_signal then
            if condition.output_signal.name == "signal-everything" then
              cc1[#cc1+1]={index=#cc1+1,count=7,signal=knownsignals.S}
            else
              cc2[#cc2+1]={index=#cc2+1,count=4,signal=condition.output_signal}
            end
          end
        end
      end
      if condition.second_signal then 
        cc2[#cc2+1]={index=#cc2+1,count=2,signal=condition.second_signal}
      end
      if condition.constant then
        cc1[#cc1+1]={index=#cc1+1,count=condition.constant,signal=knownsignals.K}
      end
      if condition.comparator then
        for i,op in pairs(deciderop) do
          if condition.comparator == op then
            cc1[#cc1+1]={index=#cc1+1,count=i,signal=knownsignals.O}
            break
          end
        end
      end
      if condition.copy_count_from_input == false then
        cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.F}
      end
    end
  end,
  [defines.control_behavior.type.generic_on_off] = ReportGenericOnOffControl,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.mining_drill] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if control.circuit_enable_disable then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.E}
    end
    if control.circuit_read_resources then
      if control.circuit_resource_read_mode == defines.control_behavior.mining_drill.resource_read_mode.this_miner then
        cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
      elseif control.circuit_resource_read_mode == defines.control_behavior.mining_drill.resource_read_mode.entire_patch then
        cc1[#cc1+1]={index=#cc1+1,count=2,signal=knownsignals.R}
      end
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.train_stop] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if control.circuit_enable_disable then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.E}
    end
    if control.read_stopped_train and control.train_stopped_signal then
      cc2[#cc2+1]={index=#cc2+1,count=4,signal=control.train_stopped_signal}
    end
    if control.read_from_train then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
    end
    if control.send_to_train == nil or control.send_to_train == true then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.T}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.inserter] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if not control.circuit_mode_of_operation or control.circuit_mode_of_operation == defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.E}
    elseif control.circuit_mode_of_operation == defines.control_behavior.inserter.circuit_mode_of_operation.set_filters then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.F}
    end
    if control.circuit_read_hand_contents then
      if not control.circuit_hand_read_mode or 
          control.circuit_hand_read_mode == defines.control_behavior.inserter.hand_read_mode.pulse then
        cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
      elseif control.circuit_hand_read_mode == defines.control_behavior.inserter.hand_read_mode.hold then
        cc1[#cc1+1]={index=#cc1+1,count=2,signal=knownsignals.R}
      end
    end
    if control.circuit_set_stack_size and control.stack_control_input_signal then
      cc2[#cc2+1]={index=#cc2+1,count=4,signal=control.stack_control_input_signal}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.lamp] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if control.use_colors then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.C}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.logistic_container] = function(control,cc1,cc2)
    if control.circuit_mode_of_operation == defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.S}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.roboport] = function(control,cc1,cc2)
    if control.read_robot_stats then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
    end

    if control.read_logistics then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.L}
    end

    if control.available_logistic_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=1,signal=control.available_logistic_output_signal}
    end
    if control.total_logistic_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=2,signal=control.total_logistic_output_signal}
    end
    if control.available_construction_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=4,signal=control.available_construction_output_signal}
    end
    if control.total_construction_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=8,signal=control.total_construction_output_signal}
    end

  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.transport_belt] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if control.circuit_enable_disable then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.E}
    end
    if control.circuit_read_hand_contents and control.circuit_contents_read_mode then
      if control.circuit_contents_read_mode == defines.control_behavior.transport_belt.content_read_mode.pulse then
        cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
      elseif control.circuit_contents_read_mode == defines.control_behavior.transport_belt.content_read_mode.hold then
        cc1[#cc1+1]={index=#cc1+1,count=2,signal=knownsignals.R}
      end
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.accumulator] = function(control,cc1,cc2)
    if control.output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=1,signal=control.output_signal}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.rail_signal] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if control.circuit_close_signal then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.E}
    end
    if control.circuit_read_signal then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
    end
    if control.red_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=4,signal=control.red_output_signal}
    end
    if control.orange_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=8,signal=control.orange_output_signal}
    end
    if control.green_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=16,signal=control.green_output_signal}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.rail_chain_signal] = function(control,cc1,cc2)
    if control.red_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=4,signal=control.red_output_signal}
    end
    if control.orange_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=8,signal=control.orange_output_signal}
    end
    if control.green_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=16,signal=control.green_output_signal}
    end
    if control.blue_output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=32,signal=control.blue_output_signal}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.wall] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    if control.circuit_open_gate then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.E}
    end
    if control.circuit_read_sensor then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
    end
    if control.output_signal then
      cc2[#cc2+1]={index=#cc2+1,count=4,signal=control.output_signal}
    end
  end,
  ---@param control BlueprintControlBehavior
  ---@param cc1 ConstantCombinatorParameters[]
  ---@param cc2 ConstantCombinatorParameters[]
  [defines.control_behavior.type.programmable_speaker] = function(control,cc1,cc2)
    ReportGenericOnOffControl(control,cc1,cc2)
    local parameters = control.circuit_parameters
    if parameters then
      if parameters.signal_value_is_pitch then
        cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.V}
      end
      if parameters.instrument_id then
        cc1[#cc1+1]={index=#cc1+1,count=parameters.instrument_id,signal=knownsignals.I}
      end
      if parameters.note_id then
        cc1[#cc1+1]={index=#cc1+1,count=parameters.note_id,signal=knownsignals.J}
      end
    end
  end,
}

---@param entity BlueprintEntity
---@param i number
---@return ConstantCombinatorParameters[][]
local function ReportBlueprintEntityInternal(entity,i)
  local entproto = game.entity_prototypes[entity.name]
  local preload = nil
  local cc1 = {}
  local cc2 = {}
  
  cc1[#cc1+1]={index=#cc1+1,count=7,signal=knownsignals.blueprint}
  cc1[#cc1+1]={index=#cc1+1,count=i,signal=knownsignals.grey}

  local item = entproto.items_to_place_this[1].name
  local itemproto = game.item_prototypes[item]
  local itemcount = 1
  if itemproto.type == "rail-planner" and itemproto.curved_rail == entproto then
    itemcount = 2
  end
  cc1[#cc1+1]={index=#cc1+1,count=itemcount,signal={type="item",name=item}}

  cc1[#cc1+1]={index=#cc1+1,count=math.floor(entity.position.x),signal=knownsignals.X}
  cc1[#cc1+1]={index=#cc1+1,count=math.floor(entity.position.y),signal=knownsignals.Y}

  if entity.direction then
    cc1[#cc1+1]={index=#cc1+1,count=entity.direction,signal=knownsignals.D}
  elseif entity.orientation then
    cc1[#cc1+1]={index=#cc1+1,count=math.floor(entity.orientation * 65535 + 0.5),signal=knownsignals.O}
  end

  if entity.recipe and remote.interfaces['recipeid'] then
    local recipeid = remote.call('recipeid','map_recipe',entity.recipe)
    if recipeid then
      cc1[#cc1+1]={index=#cc1+1,count=recipeid,signal=knownsignals.R}
    end
  end

  if entity.inventory then
    local inv = entity.inventory
    if inv.bar then 
      cc1[#cc1+1]={index=#cc1+1,count=inv.bar,signal=knownsignals.B}
    end
    if inv.filters then
      for _,filter in pairs(inv.filters) do
        if filter.name then
          if filter.index < 32 then
            cc2[#cc2+1]={index=#cc2+1,count=bit32.lshift(1,filter.index-1) ,signal={type="item",name=filter.name}}
          elseif filter.index == 32 then
            cc2[#cc2+1]={index=#cc2+1,count=-0x80000000 ,signal={type="item",name=filter.name}}
            --TODO: error signal for filters 33+ that don't match? extended report/command for more filters?
          end
        end
      end
    end
  elseif entity.bar then
    cc1[#cc1+1]={index=#cc1+1,count=entity.bar,signal=knownsignals.B}
  end

  if entity.filters then
    if entproto.type == "inserter" then
      --need to do inserter filters differently, to free bits for condition...
      for _,filter in pairs(entity.filters) do
        cc2[#cc2+1]={index=#cc2+1,count=bit32.lshift(1,filter.index + 2) ,signal={type="item",name=filter.name}}
      end
    elseif entproto.type == "loader" then
      for _,filter in pairs(entity.filters) do
        cc2[#cc2+1]={index=#cc2+1,count=1 ,signal={type="item",name=filter.name}}
      end
    end
  end

  if entity.type == "output" then 
    cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.U}
  end

  local splitterside = {left = 1, right = 2 }
  local inputside = splitterside[entity.input_priority]
  if inputside then 
    cc1[#cc1+1]={index=#cc1+1,count=inputside,signal=knownsignals.I}
  end
  local outputside = splitterside[entity.output_priority]
  if outputside then 
    cc1[#cc1+1]={index=#cc1+1,count=outputside,signal=knownsignals.O}
  end

  if entity.filter then
    cc2[#cc2+1]={index=#cc2+1,count=1,signal={type="item",name=entity.filter}}
  end

  if entity.filter_mode == "blacklist" then
    cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.B}
  end

  if entity.override_stack_size then
    cc1[#cc1+1]={index=#cc1+1,count=entity.override_stack_size,signal=knownsignals.I}
  end

  if entity.request_filters then
    for _,filter in pairs(entity.request_filters) do 
      cc2[#cc2+1]={index=#cc2+1,count=(entproto.logistic_mode == "storage" and 1) or filter.count or 1,signal={type="item",name=filter.name}}
    end
  end

  if entity.request_from_buffers then
    cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.R}
  end

  if entity.parameters then
    local parameters = entity.parameters
    if parameters.playback_volume then
      cc1[#cc1+1]={index=#cc1+1,count=parameters.playback_volume * 100,signal=knownsignals.U}
    end
    if parameters.playback_globally then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.G}
    end
    if parameters.allow_polyphony then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.P}
    end
  end
  if entity.alert_parameters then
    local parameters = entity.alert_parameters
    if parameters.show_alert then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.A}
    end
    if parameters.show_on_map then
      cc1[#cc1+1]={index=#cc1+1,count=1,signal=knownsignals.M}
    end
    if parameters.icon_signal_id then
      cc2[#cc2+1]={index=#cc1+1,count=4,signal=parameters.icon_signal_id}
    end
    if parameters.alert_message then
      preload = parameters.alert_message
    end
  end

  if entity.color then
    local color = entity.color
    cc1[#cc1+1]={index=#cc1+1,count=color.r*255,signal=knownsignals.red}
    cc1[#cc1+1]={index=#cc1+1,count=color.g*255,signal=knownsignals.green}
    cc1[#cc1+1]={index=#cc1+1,count=color.b*255,signal=knownsignals.blue}
    cc1[#cc1+1]={index=#cc1+1,count=(color.a or 1)*255,signal=knownsignals.white}
  end
  if entity.station then
    preload = entity.station
  end

  if entity.control_behavior then
    local controltype = EntityTypeToControlBehavior[entproto.type]
    if controltype then
      local special = ReportControlBehavior[controltype]
      if special then
        special(entity.control_behavior,cc1,cc2)
      end
    end
  end
  local outframes = {}
  if preload and remote.interfaces['signalstrings'] then
    outframes[#outframes+1] = {{index=1,count=1,signal=knownsignals.info}}
    outframes[#outframes+1] = remote.call('signalstrings','string_to_signals', preload)
  end
  outframes[#outframes+1] = cc1
  outframes[#outframes+1] = cc2
  return outframes
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintEntity(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      local entity = entities[i]
      local outframes = ReportBlueprintEntityInternal(entity,i)
      manager.cc2.get_or_create_control_behavior().parameters=outframes[1]
      outframes[1] = nil
      manager.morecc2 = outframes
      manager.clearcc2 = true
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintEntity(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities+1 then
      local newent = ConstructionOrder(manager,signals1,signals2,true)
      if newent then
        newent.entity_number = i
        if entities[i] then 
          if entities[i].connections then
            newent.connections = entities[i].connections
            if newent.connections["2"] then
              local hasTwo = { ["arithmetic-combinator"] = true, ["decider-combinator"] = true }
              if not hasTwo[newent.ghost_prototype.type] then
                for color,wires in pairs(newent.connections["2"]) do
                  for _,wire in pairs(wires) do
                    local farwires = entities[wire.entity_id].connections[tostring(wire.circuit_id or 1)][color]
                    for fari,farwire in pairs(farwires) do
                      if farwire.entity_id == i and farwire.circuit_id == 2 then
                        farwires[fari] = nil
                      end
                    end
                  end
                end
                newent.connections["2"] = nil
              end
            end
          end
          if entities[i].items then 
            newent.items = entities[i].items
          end
        end
        entities[i] = newent
        bp.set_blueprint_entities(entities)
      end
    end
  end
end

---@param items table<string,number>
---@return ConstantCombinatorParameters[]
local function ReportBlueprintItemRequestsInternal(items)
  local outsignals = {}
  for item,count in pairs(items) do
    outsignals[#outsignals+1]={index=#outsignals+1,count=count,signal={name=item,type="item"}}
  end
  return outsignals
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintItemRequests(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      local outsignals = ReportBlueprintItemRequestsInternal(entities[i].items)
      manager.cc2.get_or_create_control_behavior().parameters=outsignals
      manager.clearcc2 = true
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintItemRequests(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      entities[i].items = ReadItems(signals2)
      bp.set_blueprint_entities(entities)
    end
  end
end

---@param entity_id number
---@param connector_index number
---@param color string
---@param connection_index number
---@param connection table
---@return ConstantCombinatorParameters[]
local function ReportBlueprintWireInternal(entity_id,connector_index,color,connection_index,connection)
  local outsignals = {}
  
  outsignals[1]={index=1,count=1,signal=knownsignals[color .. "wire"]}

  outsignals[2]={index=2,count=entity_id,signal=knownsignals.grey}
  outsignals[3]={index=3,count=connector_index,signal=knownsignals.Z}
  outsignals[4]={index=4,count=connection_index,signal=knownsignals.X}
  
  outsignals[5]={index=5,count=connection.entity_id,signal=knownsignals.white}
  outsignals[6]={index=6,count=connection.circuit_id or 1,signal=knownsignals.Y}
  return outsignals
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintWire(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      local entity = entities[i]
      local connection_index = get_signal_from_set(knownsignals.X,signals1)
      local connector_index = get_signal_from_set(knownsignals.Z,signals1)
      local redwire = get_signal_from_set(knownsignals.redwire,signals1)
      local greenwire = get_signal_from_set(knownsignals.greenwire,signals1)

      if connector_index ~= 2 then
        connector_index = 1
      end
      if not entity.connections then return end
      local connector = entity.connections[tostring(connector_index)]
      if not connector then return end

      local color
      if redwire == 1 then
        color = "red"
      elseif greenwire == 1 then
        color = "green"
      end
      if color then
        connector = connector[color]
        if not connector then return end
      end
    
      if connector and connection_index > 0 and connection_index <= #connector then
        local connection = connector[connection_index]
        local outsignals = ReportBlueprintWireInternal(i,connector_index,color,connection_index,connection)
        manager.cc2.get_or_create_control_behavior().parameters=outsignals
        manager.clearcc2 = true
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintWire(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      local entity = entities[i]
      local connection_index = get_signal_from_set(knownsignals.X,signals1)
      local connector_index = get_signal_from_set(knownsignals.Z,signals1)
      local redwire = get_signal_from_set(knownsignals.redwire,signals1)
      local greenwire = get_signal_from_set(knownsignals.greenwire,signals1)
      local connectorstr
      if connector_index == 2 then
        connectorstr = "2"
      else
        connector_index = 1
        connectorstr = "1"
      end
      if not entity.connections then
        entity.connections = {}
      end
      if not entity.connections[connectorstr] then entity.connections[connectorstr] = {} end
      local connector = entity.connections[connectorstr]

      local color
      local colorvalue 
      if redwire == 1 or redwire == -1 then
        color = "red"
        colorvalue = redwire
      elseif greenwire == 1 or greenwire == -1 then
        color = "green"
        colorvalue = greenwire
      end
      if color then
        if not connector[color] then connector[color] = {} end
        connector = connector[color]
        if not connector then return end
      end

      if connector and connection_index > 0 and connection_index <= #connector+1 then
        if colorvalue == 1 then
          local far_entity_index = get_signal_from_set(knownsignals.white,signals1)
          if not (far_entity_index > 0 and far_entity_index <= #entities) then return end
          local far_connector_index = get_signal_from_set(knownsignals.Y,signals1)
          if far_connector_index ~= 2 then 
            far_connector_index = 1
          end
          connector[connection_index] = {
            entity_id = far_entity_index,
            circuit_id = far_connector_index,
          }
        else -- colorvalue == -1
          if connection_index == #connector+1 then return end -- don't allow the +1 when deleting
          local removedwire = connector[connection_index]
          if connection_index ~= #connector then
            connector[connection_index] = connector[#connector]
          end
          connector[#connector] = nil
          local farconnections = entities[removedwire.entity_id].connections[tostring(removedwire.circuit_id or 1)][color]
          for j,farconnection in pairs(farconnections) do
            if farconnection.entity_id == i and (farconnection.circuit_id or 1) == connector_index then
              if j ~= #farconnections then
                farconnections[j] = farconnections[#farconnections]
              end
              farconnections[#farconnections] = nil
              break
            end
          end
        end
        bp.set_blueprint_entities(entities)
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintSchedule(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      local entity = entities[i]
      local schedule_index = get_signal_from_set(knownsignals.schedule,signals2)
      if entity.schedule and schedule_index > 0 and schedule_index <= #entity.schedule then 
        local outsignals = remote.call("stringy-train-stop", "reportScheduleEntry", entity.schedule[schedule_index])[1]
        outsignals[#outsignals+1] = { index = #outsignals+1, signal = knownsignals.schedule, count = schedule_index}
        
        manager.cc2.get_or_create_control_behavior().parameters=outsignals
        manager.clearcc2 = true
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintSchedule(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local entities = bp.get_blueprint_entities() or {}
    local i = get_signal_from_set(knownsignals.grey,signals1)
    if i > 0 and i <= #entities then
      local entity = entities[i]
      local schedule_index = get_signal_from_set(knownsignals.schedule,signals2)
      if not entity.schedule then 
        entity.schedule = {}
      end
      if schedule_index > 0 and schedule_index <= #entity.schedule + 1 then 
        local newschedule = remote.call("stringy-train-stop", "parseScheduleEntry", signals2, manager.ent.surface)
        if newschedule.rail then
          newschedule.rail = nil
          newschedule.station = ""
        end
        if newschedule.station == "" and (not newschedule.wait_conditions or #newschedule.wait_conditions == 0) then 
          newschedule = nil
        end
        entity.schedule[schedule_index] = newschedule
        bp.set_blueprint_entities(entities)
      end
    end
  end
end

---@param bp LuaItemStack
---@return ConstantCombinatorParameters[]
local function ReportBlueprintSnappingInternal(bp)
  local outsignals = {}
  local snap = bp.blueprint_snap_to_grid
  if snap then
    outsignals[1]={index=1,count=snap.x,signal=knownsignals.U}
    outsignals[2]={index=2,count=snap.y,signal=knownsignals.V}
    local rel = bp.blueprint_position_relative_to_grid
    if rel then
      outsignals[3]={index=3,count=rel.x,signal=knownsignals.X}
      outsignals[4]={index=4,count=rel.y,signal=knownsignals.Y}
      outsignals[5]={index=5,count=1,signal=knownsignals.Z}
    end
  end
  return outsignals
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function ReportBlueprintSnapping(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    manager.cc2.get_or_create_control_behavior().parameters=ReportBlueprintSnappingInternal(bp)
    manager.clearcc2 = true
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function UpdateBlueprintSnapping(manager,signals1,signals2)
  ---@type LuaItemStack
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local signals = get_signals_filtered({
        u = knownsignals.U,
        v = knownsignals.V,
        x = knownsignals.X,
        y = knownsignals.Y,
        z = knownsignals.Z,
      },signals1)
    local u,v,x,y,z = signals.u or 0,signals.v or 0,signals.x or 0,signals.y or 0,signals.z or 0

    if u>0 and v>0 then
      bp.blueprint_snap_to_grid = {u,v}
      if z ~= 0 then
        bp.blueprint_position_relative_to_grid = {x,y}
      else
        bp.blueprint_position_relative_to_grid = nil
      end
    else
      bp.blueprint_snap_to_grid = nil
    end


  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function DumpBlueprint(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    local outframes = {
    --dump enough signals to recreate this blueprint from scratch
    {{index=1,count=-2,signal=knownsignals.blueprint}},
    {}, --TODO: some metadata in this frame? how many frames to expect? number of entities/tiles/etc?
    --Label
    {{index=1,count=4,signal=knownsignals.blueprint}},
    ReportLabel(manager,bp,true),
    --Icons
    {{index=1,count=5,signal=knownsignals.blueprint}},
    ReportBlueprintIconsInternal(bp),
    }
    --Tiles
    local tiles = bp.get_blueprint_tiles()
    if tiles then
      for t,tile in pairs(tiles) do
        local tilesigs = ReportBlueprintTileInternal(tile)
        tilesigs[#tilesigs+1] = {index=#tilesigs+1,count=6,signal=knownsignals.blueprint}
        tilesigs[#tilesigs+1] = {index=#tilesigs+1,count=t,signal=knownsignals.T}

        outframes[#outframes+1] = tilesigs
        outframes[#outframes+1] = {} -- tiles have no cc2 data, but everything is pairs
      end
    end

    --Entities
    local entities = bp.get_blueprint_entities()
    local entitycmds = {}
    if entities then
      for i,entity in pairs(entities) do
        -- Preload string will be before entity if needed
        local entityframes = ReportBlueprintEntityInternal(entity,i)
        for _,frame in pairs(entityframes) do
          outframes[#outframes+1] = frame
        end
        -- Item Requests after entity
        if entity.items then 
          outframes[#outframes+1] = {
            {index=1,count=8,signal=knownsignals.blueprint},
            {index=2,count=i,signal=knownsignals.grey},
          }
          outframes[#outframes+1] = ReportBlueprintItemRequestsInternal(entity.items)
        end
        -- Wire Connections after the second entity is placed
        if entity.connections then
          for connector_index,connector in pairs(entity.connections) do
            for color,connections in pairs(connector) do
              for connection_index,connection in pairs(connections) do
                if connection.entity_id <= i then
                  local outsignals = ReportBlueprintWireInternal(i,connector_index,color,connection_index,connection)
                  outsignals[#outsignals+1] = {index=#outsignals+1,count=9,signal=knownsignals.blueprint}
                  outframes[#outframes+1] = outsignals
                  outframes[#outframes+1] = {} --no cc2 data for wires
                end 
              end
            end
          end
        end
        -- Train Schedules for every Loco
        --TODO: Dedup Train Schedules somehow?
        if entity.schedule then
          for stop_index,stop in pairs(entity.schedule) do
            outframes[#outframes+1] = {
              {index=1,count=10,signal=knownsignals.blueprint},
              {index=2,count=i,signal=knownsignals.grey},
            }
            local outsignals = remote.call("stringy-train-stop", "reportScheduleEntry", stop)[1] -- array of one element for now, multiple frames for OR groups eventually
            outsignals[#outsignals+1] = {index=#outsignals+1,count=stop_index,signal=knownsignals.schedule}
            outframes[#outframes+1] = outsignals
          end
        end
      end
    end

    --write output...
    manager.cc2.get_or_create_control_behavior().parameters=outframes[1]
    outframes[1] = nil
    manager.morecc2 = outframes
    manager.clearcc2 = true
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
---@param cancel? boolean
local function DeconstructionOrder(manager,signals1,signals2,cancel)
  local area = ReadBoundingBox(signals1)

  if not signals2 then
    -- decon all
    local decon = manager.ent.surface.find_entities(area)
    for _,e in pairs(decon) do
      if cancel then
        e.cancel_deconstruction(manager.ent.force)
      else
        e.order_deconstruction(manager.ent.force)
      end
    end
  else
    -- filtered decon
    for _,signal in pairs(signals2) do
      if signal.signal.type == "item" then
        local itemproto = game.item_prototypes[signal.signal.name]
        if itemproto.place_result then
          local entname = itemproto.place_result.name
          for _,d in pairs(manager.ent.surface.find_entities_filtered{
            name = entname, area = area}) do

            if cancel then
              d.cancel_deconstruction(manager.ent.force)
            else
              d.order_deconstruction(manager.ent.force)
            end
          end
        end
      elseif signal.signal.type == "virtual" then
        if signal.signal.name == "signal-T" then
          for _,d in pairs(manager.ent.surface.find_entities_filtered{
            type = 'tree', area = area}) do

            if cancel then
              d.cancel_deconstruction(manager.ent.force)
            else
              d.order_deconstruction(manager.ent.force)
            end
          end
        elseif signal.signal.name== "signal-R" then
          for _,d in pairs(manager.ent.surface.find_entities_filtered{
            name = global.deconrocks, area = area}) do

            if cancel then
              d.cancel_deconstruction(manager.ent.force)
            else
              d.order_deconstruction(manager.ent.force)
            end
          end
        elseif signal.signal.name== "signal-C" then
          for _,d in pairs(manager.ent.surface.find_entities_filtered{
            type = "cliff", area = area}) do

            if cancel then
              d.cancel_deconstruction(manager.ent.force)
            else
              d.order_deconstruction(manager.ent.force)
            end
          end
        end
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function DeliveryOrder(manager,signals1,signals2)
  local ent = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signals1,false,{x=0.5,y=0.5})}[1]
  if not (ent and ent.valid) then return end

  if signals2 then
    local items = ReadItems(signals2)
    if next(items,nil) then
      if ent.name == "entity-ghost" or ent.name == "item-request-proxy" then
        -- just set the ghost requests
        local reqs = ent.item_requests
        for name,count in pairs(items) do
          reqs[name] = (reqs[name] or 0) + count
        end
        ent.item_requests = reqs
      else
        ent.surface.create_entity{
          name='item-request-proxy',
          force=ent.force,
          position=ent.position,
          target=ent,
          modules=items
        }
      end
    end
  end
end


---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
---@param flare string
local function ArtilleryOrder(manager,signals1,signals2,flare)
  manager.ent.surface.create_entity{
    name=flare,
    force=manager.ent.force,
    position=ReadPosition(signals1),
    movement={0,0},
    frame_speed = 1,
    vertical_speed = 0,
    height = 0,
  }
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function SetPreloadString(manager,signals1,signals2)
  -- read string and color from signals2, store in manager.preloadstring and manager.preloadcolor
  if remote.interfaces['signalstrings'] and signals2 then
    manager.preloadstring = remote.call('signalstrings','signals_to_string',signals2,true)
    local a = get_signal_from_set(knownsignals.white,signals2)
    if a > 0 and a <= 255 then
      local color = ReadColor(signals2)
      color.a = a
      manager.preloadcolor = color
    else
      manager.preloadcolor = nil
    end
  else
    manager.preloadstring = nil
    manager.preloadcolor = nil
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function SetBlueprintAnchor(manager,signals1,signals2)
  -- read item and "relative to conman" flag
  manager.relative = get_signal_from_set(knownsignals.R,signals1) ~= 0

  manager.anchor = nil
  manager.anchor_tile = nil
  for _,signal in pairs(signals1) do
    if signal.signal.type == "item" then
      local itemproto = game.item_prototypes[signal.signal.name]
      local entproto = itemproto.place_result
      local tileresult = itemproto.place_as_tile_result

      if itemproto.type == "rail-planner" then
        if signal.count == 1 then
          entproto = itemproto.straight_rail
        elseif signal.count == 2 then
          entproto = itemproto.curved_rail
        end
      end

      if entproto then
        manager.anchor = entproto
        break -- once we're found one, get out of the loop, so we don't build multiple things.
      elseif tileresult then
        manager.anchor_tile = tileresult.result
        break -- once we're found one, get out of the loop, so we don't build multiple things.
      end
    end
  end
end

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
local function GetBlueprintAnchor(manager,signals1,signals2)
  local outsignals = {
    { index = 1, signal = knownsignals.info, count = 2}
  }
  if manager.relative then
    outsignals[#outsignals+1] = { index = #outsignals+1, signal = knownsignals.R, count = 1}
  end

  if manager.anchor then
    if not manager.anchor.valid then
      manager.anchor = nil
    else
      local item = manager.anchor.items_to_place_this[1].name
      local itemproto = game.item_prototypes[item]
      local itemcount = 1
      if itemproto.type == "rail-planner" and itemproto.curved_rail == manager.anchor then
        itemcount = 2
      end
      outsignals[#outsignals+1]={index=#outsignals+1,count=itemcount,signal={type="item",name=item}}
    end
  elseif manager.anchor_tile then
    if not manager.anchor_tile.valid then
      manager.anchor_tile = nil
    else
      local item = manager.anchor_tile.items_to_place_this[1].name
      outsignals[#outsignals+1]={index=#outsignals+1,count=1,signal={type="item",name=item}}
    end
  end
  
  manager.cc2.get_or_create_control_behavior().parameters=outsignals
  manager.clearcc2 = true
end

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

local bp_signal_functions = {
  [-5] = InsertBlueprintToBook,
  [-4] = TakeBlueprintFromBook,
  [-3] = DestroyBlueprint,
  [-2] = ClearOrCreateBlueprint,
  [-1] = EjectBlueprint,
  [1] = DeployBlueprint,
  [2] = CaptureBlueprint,
  [3] = ReportBlueprintBoM,
  [4] = ReadWrite(ReportBlueprintLabel,UpdateBlueprintLabel),
  [5] = ReadWrite(ReportBlueprintIcons,UpdateBlueprintIcons),
  [6] = ReadWrite(ReportBlueprintTile,UpdateBlueprintTile),
  [7] = ReadWrite(ReportBlueprintEntity,UpdateBlueprintEntity),
  [8] = ReadWrite(ReportBlueprintItemRequests,UpdateBlueprintItemRequests),
  [9] = ReadWrite(ReportBlueprintWire,UpdateBlueprintWire),
  [10] = ReadWrite(ReportBlueprintSchedule,UpdateBlueprintSchedule),
  [11] = DumpBlueprint,
  [12] = ReadWrite(ReportBlueprintSnapping,UpdateBlueprintSnapping),
}

local book_signal_functions = {
  [-6] = ChangeDirBlueprintBook,
  [-5] = ListBlueprintBook,
  [-4] = ReadWrite(ReportBlueprintBookLabel,UpdateBlueprintBookLabel),
  [-3] = DestroyBlueprintBook,
  [-2] = ClearOrCreateBlueprintBook,
  [-1] = EjectBlueprintBook,
}

local info_signal_functions = {
  [1] = SetPreloadString,
  [2] = ReadWrite(GetBlueprintAnchor,SetBlueprintAnchor),
}

---@param manager ConManManager
local function onTickManager(manager)
  if manager.morecc2 then
    local i,nextframe = next(manager.morecc2)
    if nextframe then
      manager.cc2.get_or_create_control_behavior().parameters=nextframe
      manager.morecc2[i] = nil
      return
    else
      manager.morecc2 = nil
    end
  end
  if manager.clearcc2 then
    manager.clearcc2 = nil
    manager.cc2.get_or_create_control_behavior().parameters=nil
  end

  local signals1 = manager.cc1.get_merged_signals()
  if not signals1 then return end
  local signals2 = manager.cc2.get_merged_signals()

  local bpsig = get_signal_from_set(knownsignals.blueprint,signals1)
  local bpfunc = bp_signal_functions[bpsig] -- commands using blueprint item, indexed by command number
  if bpfunc then
    return bpfunc(manager,signals1,signals2)
  end

  local booksig = get_signal_from_set(knownsignals.blueprint_book,signals1)
  local bookfunc = book_signal_functions[booksig] -- commands using blueprint book item, indexed by command number
  if bookfunc then
    return bookfunc(manager,signals1,signals2)
  end
  if get_signal_from_set(knownsignals.conbot,signals1) == 1 then
    -- check for conbot=1, build a thing
    return ConstructionOrder(manager,signals1,signals2)
  end
  if get_signal_from_set(knownsignals.logbot,signals1) == 1 then
    return DeliveryOrder(manager,signals1,signals2)
  end
  if get_signal_from_set(knownsignals.redprint,signals1) == 1 then
    -- redprint=1, decon orders
    return DeconstructionOrder(manager,signals1,signals2)
  end
  if get_signal_from_set(knownsignals.redprint,signals1) == -1 then
    -- redprint=-1, cancel decon orders
    return DeconstructionOrder(manager,signals1,signals2,true)
  end
  if get_signal_from_set(knownsignals.redwire,signals1) == 1 then
    return ConnectWire(manager,signals1,signals2,defines.wire_type.red)
  end
  if get_signal_from_set(knownsignals.greenwire,signals1) == 1 then
    return ConnectWire(manager,signals1,signals2,defines.wire_type.green)
  end
  if get_signal_from_set(knownsignals.coppercable,signals1) == 1 then
    return ConnectWire(manager,signals1,signals2)
  end
  if get_signal_from_set(knownsignals.redwire,signals1) == -1 then
    return ConnectWire(manager,signals1,signals2,defines.wire_type.red,true)
  end
  if get_signal_from_set(knownsignals.greenwire,signals1) == -1 then
    return ConnectWire(manager,signals1,signals2,defines.wire_type.green,true)
  end
  if get_signal_from_set(knownsignals.coppercable,signals1) == -1 then
    return ConnectWire(manager,signals1,signals2,nil,true)
  end
  local siginfo = get_signal_from_set(knownsignals.info,signals1)
  local info_func = info_signal_functions[siginfo]
  if info_func then
    return info_func(manager,signals1,signals2)
  end
  if script.active_mods["stringy-train-stop"] then
    local sigsched = get_signal_from_set(knownsignals.schedule,signals1)
    if sigsched == 1 or (sigsched > 0 and manager.schedule and sigsched <= #manager.schedule+1) then
      if not manager.schedule then manager.schedule = {} end
      local schedule = remote.call("stringy-train-stop", "parseScheduleEntry", signals1, manager.ent.surface)
      manager.schedule[sigsched] = schedule
      return
    elseif sigsched == -1 and manager.schedule then
      local ent = manager.ent.surface.find_entities_filtered{
        type={'locomotive','cargo-wagon','fluid-wagon','artillery-wagon'},
        force=manager.ent.force,
        position=ReadPosition(signals1)}[1]
      if ent and ent.valid then
        ent.train.manual_mode = true
        ent.train.schedule = { current = 1, records = manager.schedule}
        ent.train.manual_mode = false
        manager.schedule = {}
      end
      return
    end
  end

  for _,r in pairs(global.artyremotes) do
    if get_signal_from_set(r.signal,signals1) == 1 then
      return ArtilleryOrder(manager,signals1,signals2,r.flare)
    end
  end
end


local function onTick()
  if global.managers then
    for _,manager in pairs(global.managers) do
      if not (manager.ent.valid and manager.cc1.valid and manager.cc2.valid) then
        -- if anything is invalid, tear it all down
        if manager.ent.valid then manager.ent.destroy() end
        if manager.cc1.valid then manager.cc1.destroy() end
        if manager.cc2.valid then manager.cc2.destroy() end
        global.managers[_] = nil
      else
        onTickManager(manager)
      end
    end
  end
end

---@param manager ConManManager
---@param position Position
---@return LuaEntity
local function CreateControl(manager,position)
  local ghost = manager.surface.find_entity('entity-ghost', position)
  if ghost then
    -- if there's a ghost here, just claim it!
    _,ghost = ghost.revive()
  else
    -- or a pre-built one, if it was built in editor and script.dat cleared...
    ghost = manager.surface.find_entity('conman-control', position)
  end

  local ent = ghost or manager.surface.create_entity{
      name='conman-control',
      position = position,
      force = manager.force
    }

  ent.operable=false
  ent.minable=false
  ent.destructible=false

  return ent
end

---@param ent LuaEntity
local function onBuilt(ent)
  if ent.name == "conman" then
    ent.active = false

    local cc1 = CreateControl(ent, {x=ent.position.x-1,y=ent.position.y+1.5})
    local cc2 = CreateControl(ent, {x=ent.position.x+1,y=ent.position.y+1.5})

    if not global.managers then global.managers = {} end
    global.managers[ent.unit_number]={ent=ent, cc1 = cc1, cc2 = cc2}

  end
end

local function reindex_rocks()
  local rocks={}
  for name,entproto in pairs(game.entity_prototypes) do
    if entproto.count_as_rock_for_filtered_deconstruction  then
      rocks[#rocks+1] = name
    end
  end
  global.deconrocks = rocks
end

local function reindex_remotes()
  local artyremotes={}
  for name,itemproto in pairs(game.get_filtered_item_prototypes{{filter="type",type="capsule"}}) do
    if itemproto.capsule_action.type == "artillery-remote" then
      artyremotes[name] = { signal = {name=name,type="item"}, flare = itemproto.capsule_action.flare }
    end
  end
  global.artyremotes = artyremotes
end

script.on_init(function()
  -- Index for new install
  reindex_rocks()
  reindex_remotes()

  -- Scan for pre-built ConMan in the world already...
  for _,surface in pairs(game.surfaces) do
    for _,entity in pairs(surface.find_entities_filtered{name="conman"}) do
      onBuilt(entity)
    end
  end
end
)

script.on_configuration_changed(function(data)
  -- when any mods change, reindex
  reindex_remotes()
  reindex_rocks()
end
)


script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_built_entity, function(event) onBuilt(event.created_entity) end)
script.on_event(defines.events.on_robot_built_entity, function(event) onBuilt(event.created_entity) end)
script.on_event(defines.events.on_entity_cloned, function(event) onBuilt(event.destination) end)
script.on_event(defines.events.script_raised_built, function(event) onBuilt(event.entity) end)
script.on_event(defines.events.script_raised_revive, function(event) onBuilt(event.entity) end)

remote.add_interface('conman',{
  --TODO: call to register items for custom decoding into ghost tags?


  ---@param manager_id number
  ---@return string|nil
  read_preload_string = function(manager_id)
    return global.managers[manager_id] and global.managers[manager_id].preloadstring
  end,
  ---@param manager_id number
  ---@return Color|nil
  read_preload_color = function(manager_id)
    return global.managers[manager_id] and global.managers[manager_id].preloadcolor
  end,
  ---@param manager_id number
  ---@param str string
  set_preload_string = function(manager_id,str)
    if global.managers[manager_id] then
      global.managers[manager_id].preloadstring = str
    end
  end,
  ---@param manager_id number
  ---@param color Color
  set_preload_color = function(manager_id,color)
    if global.managers[manager_id] then
      global.managers[manager_id].preloadcolor = color
    end
  end,
})