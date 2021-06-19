local cmdefines = require("__conman__/defines.lua")
local arithop = cmdefines.arithop
local deciderop = cmdefines.deciderop
local specials = cmdefines.specials
local EntityTypeToControlBehavior = cmdefines.EntityTypeToControlBehavior
local knownsignals = require("knownsignals")
local signal_util = require("signal_util")
local get_signal_from_set = signal_util.get_signal_from_set

local signal_concepts = require("signal_concepts")
local ReadPosition = signal_concepts.ReadPosition
local ReadItems = signal_concepts.ReadItems
local ReadSignalList = signal_concepts.ReadSignalList

local ConstructionOrderEntitySpecific = require("entity_construction_order")


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

---@param manager ConManManager
---@param signals1 Signal[]
---@param signals2 Signal[]
---@param forblueprint? boolean
---@return BlueprintEntity|nil
local function ConstructionOrder(manager,signals1,signals2,forblueprint)
  local position = ReadPosition(not forblueprint and manager,signals1)
  local createorder = {
    name='entity-ghost',
    position = position,
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

return ConstructionOrder