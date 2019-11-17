function get_signal_from_set(signal,set)
  for _,sig in pairs(set) do
    if sig.signal.type == signal.type and sig.signal.name == signal.name then
      return sig.count
    end
  end
  return 0
end

function get_signals_filtered(filters,signals)
  --   filters = {
  --  SignalID,
  --  }
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


local function ReadPosition(signals,secondary,offset)
  if not offset then offset=0.5 end
  if not secondary then
    local p = get_signals_filtered(signalsets.position1,signals)
    return {
      x = (p.x or 0)+offset,
      y = (p.y or 0)+offset,
    }
  else
    local p = get_signals_filtered(signalsets.position2,signals)
    return {
      x = (p.x or 0)+offset,
      y = (p.y or 0)+offset,
    }
  end
end

local function ReadColor(signals)
  return get_signals_filtered(signalsets.color,signals)
end

local function ReadBoundingBox(signals)
  -- adjust offests to make *inclusive* selection
  return {ReadPosition(signals,false,0),ReadPosition(signals,true,1)}
end

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

local splitterside = {
  "left",
  "right",
}

local function nocc2(createorder,entproto,signals1,signals2)
  createorder.usecc2items=false
end
local ConstructionOrderEntitySpecific =
{
  ["assembling-machine"] = function(createorder,entproto,signals1,signals2)
    --set recipe if recipeid lib available
    if remote.interfaces['recipeid'] then
      createorder.recipe = remote.call('recipeid','map_recipe', get_signal_from_set(knownsignals.R,signals1))
    end
  end,
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
  ["splitter"] = function(createorder,entproto,signals1,signals2)
    createorder.input_priority = splitterside[get_signal_from_set(knownsignals.I,signals1)] or "none"
    createorder.output_priority = splitterside[get_signal_from_set(knownsignals.O,signals1)] or "none"

    createorder.filter = next(ReadItems(signals2,1))
    createorder.usecc2items=false
  end,
  ["underground-belt"] = function(createorder,entproto,signals1,signals2)
    if get_signal_from_set(knownsignals.U,signals1) ~= 0 then 
      createorder.type = "output"
    else
      createorder.type = "input"
    end
    createorder.usecc2items=false
  end,
  ["loader"] = function(createorder,entproto,signals1,signals2)
    if get_signal_from_set(knownsignals.U,signals1) ~= 0 then 
      createorder.type = "output"
    else
      createorder.type = "input"
    end
    createorder.usecc2items=false
  end,
  ["train-stop"] = function(createorder,entproto,signals1,signals2)
    createorder.usecc2items=false
    local a = get_signal_from_set(knownsignals.white,signals1)
    if a > 0 and a <= 256 then
      createorder.color = ReadColor(signals1)
      createorder.color.a = a
    end
  end,
  ["locomotive"] = function(createorder,entproto,signals1,signals2)
    local a = get_signal_from_set(knownsignals.white,signals1)
    if a > 0 and a <= 256 then
      createorder.color = ReadColor(signals1)
      createorder.color.a = a
    end
    -- un-offset locos, they don't snap very well apparently
    createorder.position.x = createorder.position.x - 0.5
    createorder.position.y = createorder.position.y - 0.5
    
  end,
  ["cargo-wagon"] = function(createorder,entproto,signals1,signals2)
    createorder.inventory = {
      bar = createorder.bar,
      filters = ReadInventoryFilters(signals2, entproto.get_inventory_size(defines.inventory.cargo_wagon))
    }
    createorder.bar = nil
    -- un-offset cargo wagons, they don't snap very well apparently
    createorder.position.x = createorder.position.x - 0.5
    createorder.position.y = createorder.position.y - 0.5
    local a = get_signal_from_set(knownsignals.white,signals1)
    if a > 0 and a <= 256 then
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
  ["constant-combinator"] = nocc2,
  ["arithmetic-combinator"] = nocc2,
  ["decider-combinator"] = nocc2,
}

local function ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)
  local siglist = {}
  if signals2 then
    siglist = ReadSignalList(signals2)
  end
  local sigmode = get_signal_from_set(knownsignals.S,signals1)
  if sigmode == 3 then
    siglist[1] = specials.any
  elseif sigmode == 4 then
    siglist[1] = specials.any
  elseif sigmode == 5 then
    siglist[1] = specials.every
  elseif sigmode == 6 then
    siglist[1] = specials.every
  end

  control.circuit_condition={ condition = {
    first_signal = siglist[1],
    second_signal = siglist[2],
    constant = get_signal_from_set(knownsignals.K,signals1),
    comparator =  deciderop[get_signal_from_set(knownsignals.O,signals1)] or "<",
    }}

  -- for more complex controls to read additional signals
  return siglist
end

local ConstructionOrderControlBehavior =
{
  [defines.control_behavior.type.constant_combinator] = function(ghost,control,manager,signals1,signals2)
    local filters = {}
    if signals2 then
      for i,s in pairs(signals2) do
        filters[#filters+1]={index = #filters+1, count = s.count, signal = s.signal}
      end
    end
    control.parameters={parameters=filters}
  end,
  [defines.control_behavior.type.arithmetic_combinator] = function(ghost,control,manager,signals1,signals2)
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
    end

    control.parameters={parameters = {
      first_signal = siglist[1],
      second_signal = siglist[2],
      first_constant = get_signal_from_set(knownsignals.J,signals1),
      second_constant = get_signal_from_set(knownsignals.K,signals1),
      operation = arithop[get_signal_from_set(knownsignals.O,signals1)] or "*",
      output_signal = siglist[3],
      }}
  end,
  [defines.control_behavior.type.decider_combinator] = function(ghost,control,manager,signals1,signals2)
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

    control.parameters={parameters = {
      first_signal = siglist[1],
      second_signal = siglist[2],
      constant = get_signal_from_set(knownsignals.K,signals1),
      comparator =  deciderop[get_signal_from_set(knownsignals.O,signals1)] or "<",
      output_signal = siglist[3],
      copy_count_from_input = get_signal_from_set(knownsignals.F,signals1) == 0,
      }}
  end,
  [defines.control_behavior.type.generic_on_off] = ReadGenericOnOffControl,
  [defines.control_behavior.type.mining_drill] = function(ghost,control,manager,signals1,signals2)
    ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

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
  end,
  [defines.control_behavior.type.train_stop] = function(ghost,control,manager,signals1,signals2)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

    control.enable_disable = get_signal_from_set(knownsignals.E,signals1) ~= 0
    control.read_from_train = get_signal_from_set(knownsignals.R,signals1) ~= 0
    control.send_to_train = get_signal_from_set(knownsignals.T,signals1) ~= 0

    if siglist[3] then
      control.stopped_train_signal = siglist[3]
      control.read_stopped_train = true
    else
      control.read_stopped_train = false
    end
  end,
  [defines.control_behavior.type.inserter] = function(ghost,control,manager,signals1,signals2,forblueprint)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

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
      control.circuit_stack_control_signal = siglist[3]
    end

    for i=1,ghost.ghost_prototype.filter_count do 
      if siglist[i+3] and siglist[i+3].type == "item" then 
        ghost.set_filter(i, siglist[i+3].name)
      else
        ghost.set_filter(i, nil)
      end
    end
  end,
  [defines.control_behavior.type.lamp] = function(ghost,control,manager,signals1,signals2)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)
    control.use_colors = get_signal_from_set(knownsignals.C,signals1) ~= 0
  end,
  [defines.control_behavior.type.logistic_container] = function(ghost,control,manager,signals1,signals2)
    if ghost.ghost_prototype.logistic_mode == "requester" or ghost.ghost_prototype.logistic_mode == "buffer" then
      if get_signal_from_set(knownsignals.R,signals1) ~= 0 then 
        control.circuit_mode_of_operation = defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests
      end
    end    
  end,
  [defines.control_behavior.type.roboport] = function(ghost,control,manager,signals1,signals2)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end

    if get_signal_from_set(knownsignals.R,signals1) ~= 0 then
      control.mode_of_operations = defines.control_behavior.roboport.circuit_mode_of_operation.read_robot_stats	
    else
      control.mode_of_operations = defines.control_behavior.roboport.circuit_mode_of_operation.read_logistics	
    end      
    
    control.available_logistic_output_signal = siglist[1]
    control.total_logistic_output_signal = siglist[2]
    control.available_construction_output_signal = siglist[3]
    control.total_construction_output_signal = siglist[4]
  end,
  [defines.control_behavior.type.transport_belt] = function(ghost,control,manager,signals1,signals2)
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)
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
  end,
  [defines.control_behavior.type.accumulator] = function(ghost,control,manager,signals1,signals2)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end
    
    control.output_signal = siglist[1]
  end,
  [defines.control_behavior.type.rail_signal] = function(ghost,control,manager,signals1,signals2)
    -- Rail doesn't actually inheret from Generic, but it's close enough to work
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

    control.close_signal = get_signal_from_set(knownsignals.E,signals1) ~= 0
    control.read_signal = get_signal_from_set(knownsignals.R,signals1) ~= 0
    
    control.red_signal = siglist[3]
    control.orange_signal = siglist[4]
    control.green_signal = siglist[5]
  end,
  [defines.control_behavior.type.rail_chain_signal] = function(ghost,control,manager,signals1,signals2)
    local siglist = {}
    if signals2 then
      siglist = ReadSignalList(signals2)
    end
    
    control.red_signal = siglist[3]
    control.orange_signal = siglist[4]
    control.green_signal = siglist[5]
    control.blue_signal = siglist[6]
  end,
  [defines.control_behavior.type.wall] = function(ghost,control,manager,signals1,signals2)
    -- Wall doesn't actually inheret from Generic, but it's close enough to work
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

    control.open_gate = get_signal_from_set(knownsignals.E,signals1) ~= 0
    control.read_sensor = get_signal_from_set(knownsignals.R,signals1) ~= 0
    
    control.output_signal = siglist[3]
  end,
  [defines.control_behavior.type.programmable_speaker] = function(ghost,control,manager,signals1,signals2)
    -- Speaker doesn't actually inheret from Generic, but it's close enough to work
    local siglist = ReadGenericOnOffControl(ghost,control,manager,signals1,signals2)

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

local function ConstructionOrder(manager,signals1,signals2,forblueprint)
  local createorder = {
    name='entity-ghost',
    position = ReadPosition(signals1),
    force = manager.ent.force,
    expires = false,
    direction = get_signal_from_set(knownsignals.D,signals1),
    usecc2items = true
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
        break -- once we're found one, get out of the loop, so we don't build multiple things.
      end
    end
  end

  if createorder.inner_name then
    if not forblueprint then
      local ghost =  manager.ent.surface.create_entity(createorder)
      if ghost and ghost.name == "entity-ghost" then
        local control = ghost.get_or_create_control_behavior()
        if control and control.valid then
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
      end
    elseif ghost.name == "entity-ghost" then --forblueprint
      game.print(serpent.block(createorder))
      local controltype = EntityTypeToControlBehavior[createorder.ghost_prototype.type]
      if controltype then
        -- enough fake objects for the various control specific stuff...
        local control = { parameters = {} }
        createorder.control_behavior = control
        createorder.filters = {}
        createorder.set_filter = function(i,name)
          filters[i] = name
        end
        local special = ConstructionOrderControlBehavior[controltype]
        if special then
          special(createorder,control,manager,signals1,signals2,true)
        end
        --clean up a bit, ready for a bp...
        createorder.name = createorder.inner_name
        createorder.inner_name = nil
        createorder.set_filter = nil
        createorder.ghost_prototype = nil
      end
      return createorder
    end
  end
end

local function EjectBlueprint(manager)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local outInv = manager.ent.get_inventory(defines.inventory.assembling_machine_output)
  outInv[1].set_stack(inInv[1])
  inInv[1].clear()
end

local function EjectBlueprintBook(manager)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local outInv = manager.ent.get_inventory(defines.inventory.assembling_machine_output)
  outInv[2].set_stack(inInv[2])
  inInv[2].clear()
end

local function GetBlueprint(manager, signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local bp = inInv[1]
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then return bp end
  local book = inInv[2]
  --check if there actually is a blueprint book.
  if book.valid and book.valid_for_read and book.is_blueprint_book then bp = book.get_inventory(defines.inventory.item_main)[page] end
  return bp
end

local function ClearOrCreateBlueprint(manager,signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  inInv[1].set_stack("blueprint")
end

local function DestroyBlueprint(manager,signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  inInv[1].clear()
end

local function ClearOrCreateBlueprintBook(manager,signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  inInv[2].set_stack("blueprint-book")
end

local function DestroyBlueprintBook(manager,signals1)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  inInv[2].clear()
end

local function DeployBlueprint(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read and bp.is_blueprint_setup() then

    local force_build = get_signal_from_set(knownsignals.F,signals1)==1

    bp.build_blueprint{
      surface=manager.ent.surface,
      force=manager.ent.force,
      position=ReadPosition(signals1),
      direction = get_signal_from_set(knownsignals.D,signals1),
      force_build= force_build,
    }
  end
end

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
    -- set or clear label and color from cc2
    if remote.interfaces['signalstrings'] and signals2 then
      bp.label = remote.call('signalstrings','signals_to_string',signals2,true)

      local a = get_signal_from_set(knownsignals.white,signals2)
      if a > 0 and a <= 256 then
        local color = ReadColor(signals2)
        color.a = a
        bp.label_color = color
      else
        bp.label_color = { r=1, g=1, b=1, a=1 }
      end

    else
      bp.label = ''
      bp.label_color = { r=1, g=1, b=1, a=1 }
    end
  end
end

local function ConnectWire(manager,signals1,signals2,color,disconnect)
  local z = get_signal_from_set(knownsignals.Z,signals1)
  if not (z>0) then z=1 end

  local w = get_signal_from_set(knownsignals.W,signals1)
  if not (w>0) then w=1 end

  local ent1 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signals1)}[1]
  local ent2 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signals1,true)}[1]

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

local function ReportLabel(manager,item)
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
  manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
  manager.clearcc2 = true
end

local function ReportBlueprintLabel(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read then
    ReportLabel(manager,bp)
  end
end

local function ReportBlueprintBookLabel(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local book = inInv[2]
  if book.valid and book.valid_for_read and book.is_blueprint_book then 
    ReportLabel(manager,book)
  end
end

local function UpdateItemLabel(item,signals2)
  -- set or clear label and color from cc2
  if remote.interfaces['signalstrings'] and signals2 then
    item.label = remote.call('signalstrings','signals_to_string',signals2,true)
    local a = get_signal_from_set(knownsignals.white,signals2)
    if a > 0 and a <= 256 then
      local color = ReadColor(signals2)
      color.a = a
      item.label_color = color
    else
      item.label_color = { r=1, g=1, b=1, a=1 }
    end
  else
    item.label = ''
    item.label_color = { r=1, g=1, b=1, a=1 }
  end
end

local function UpdateBlueprintLabel(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  local outsignals = {}
  if bp.valid and bp.valid_for_read and bp.is_blueprint_setup() then
    UpdateItemLabel(bp,signals2)
  end
end

local function UpdateBlueprintBookLabel(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local book = inInv[2]
  if book.valid and book.valid_for_read and book.is_blueprint_book then 
    UpdateItemLabel(book,signals2)
  end
end

local function ReportBlueprintBookCount(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local book = inInv[2]
  if book.valid and book.valid_for_read and book.is_blueprint_book then 
    local outsignals = {
      {index=1,count=book.get_inventory(defines.inventory.item_main).get_item_count(), signal=knownsignals.info }
    }
    manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
    manager.clearcc2 = true
  end
end

local function InsertBlueprintToBook(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local bp = inInv[1]
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then return end
  local book = inInv[2]
  --check if there actually is a blueprint book.
  if bp.valid and bp.valid_for_read and book.valid and book.valid_for_read and book.is_blueprint_book then 
    book.get_inventory(defines.inventory.item_main)[page].set_stack(bp)
    bp.clear()
  end
end

local function TakeBlueprintFromBook(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local bp = inInv[1]
  local page = get_signal_from_set(knownsignals.blueprint_book,signals1)
  if not (page > 0) then return end
  local book = inInv[2]
  --check if there actually is a blueprint book.
  if bp.valid and bp.valid_for_read and book.valid and book.valid_for_read and book.is_blueprint_book then 
    local bookinv = book.get_inventory(defines.inventory.item_main)
    if page <= bookinv.get_item_count() then
    bp.set_stack(bookinv[page])
    bookinv[page].clear()
  end
end

local function ReportBlueprintBoM(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  local outsignals = {}
  if bp.valid and bp.valid_for_read then
    -- BoM signals
    for k,v in pairs(bp.cost_to_build) do
      outsignals[#outsignals+1]={index=#outsignals+1,count=v,signal={name=k,type="item"}}
    end
  end
  manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
  manager.clearcc2 = true
end

local function ReportBlueprintIcons(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  local outsignals = {}
  if bp.valid and bp.valid_for_read then
    for _,icon in pairs(bp.blueprint_icons) do
      outsignals[#outsignals+1]={index=#outsignals+1,count=bit32.lshift(1,icon.index - 1),signal=icon.signal}
    end
  end
  manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
  manager.clearcc2 = true
end

local function UpdateBlueprintIcons(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  if bp.valid and bp.valid_for_read and signals2 then
    siglist = ReadSignalList(signals2)
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

local function ReportBlueprintTile(manager,signals1,signals2)
  local bp = GetBlueprint(manager,signals1)
  local outsignals = {}
  if bp.valid and bp.valid_for_read then
    local tiles = bp.get_blueprint_tiles()
    local t = get_signal_from_set(knownsignals.T,signals1)
    
    if t > 0 and t <= #tiles then
      local tile = tiles[t]
      local item = game.tile_prototypes[tile.name].items_to_place_this[1]
      outsignals[1]={index=1,count=1,signal={type="item",name=item.name}}
      outsignals[2]={index=2,count=tile.position.x,signal=knownsignals.X}
      outsignals[3]={index=3,count=tile.position.y,signal=knownsignals.Y}
    end
  end
  manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
  manager.clearcc2 = true
end

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

local function DeliveryOrder(manager,signals1,signals2)

  local ent = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signals1)}[1]
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
  [7] = UpdateBlueprintEntity,
  --TODO: read/write blueprint tiles/entities
}

local book_signal_functions = {
  [-5] = ReportBlueprintBookCount,
  [-4] = ReadWrite(ReportBlueprintBookLabel,UpdateBlueprintBookLabel),
  [-3] = DestroyBlueprintBook,
  [-2] = ClearOrCreateBlueprintBook,
  [-1] = EjectBlueprintBook,

}

local function onTickManager(manager)
  
  if manager.clearcc2 then
    manager.clearcc2 = nil
    manager.cc2.get_or_create_control_behavior().parameters=nil
  end
  

  local signals1 = manager.cc1.get_merged_signals()
  if signals1 then
    local signals2 = manager.cc2.get_merged_signals()
    

    local bpsig = get_signal_from_set(knownsignals.blueprint,signals1)
    local bpfunc = bp_signal_functions[bpsig] -- commands using blueprint item, indexed by command number
    if bpfunc then      
      bpfunc(manager,signals1,signals2)
    else
      local booksig = get_signal_from_set(knownsignals.blueprint_book,signals1)
      local bookfunc = book_signal_functions[booksig] -- commands using blueprint book item, indexed by command number
      if bookfunc then      
        bpfunc(manager,signals1,signals2)
      elseif get_signal_from_set(knownsignals.conbot,signals1) == 1 then
        -- check for conbot=1, build a thing
        ConstructionOrder(manager,signals1,signals2)
      elseif get_signal_from_set(knownsignals.logbot,signals1) == 1 then
        DeliveryOrder(manager,signals1,signals2)

      elseif get_signal_from_set(knownsignals.redprint,signals1) == 1 then
        -- redprint=1, decon orders
        DeconstructionOrder(manager,signals1,signals2)
      elseif get_signal_from_set(knownsignals.redprint,signals1) == -1 then
        -- redprint=-1, cancel decon orders
        DeconstructionOrder(manager,signals1,signals2,true)

      elseif get_signal_from_set(knownsignals.redwire,signals1) == 1 then
        ConnectWire(manager,signals1,signals2,defines.wire_type.red)
      elseif get_signal_from_set(knownsignals.greenwire,signals1) == 1 then
        ConnectWire(manager,signals1,signals2,defines.wire_type.green)
      elseif get_signal_from_set(knownsignals.coppercable,signals1) == 1 then
        ConnectWire(manager,signals1,signals2)
      elseif get_signal_from_set(knownsignals.redwire,signals1) == -1 then
        ConnectWire(manager,signals1,signals2,defines.wire_type.red,true)
      elseif get_signal_from_set(knownsignals.greenwire,signals1) == -1 then
        ConnectWire(manager,signals1,signals2,defines.wire_type.green,true)
      elseif get_signal_from_set(knownsignals.coppercable,signals1) == -1 then
        ConnectWire(manager,signals1,signals2,nil,true)
      elseif get_signal_from_set(knownsignals.info,signals1) == 1 then
        -- read string and color from signals2, store in manager.preloadstring and manager.preloadcolor
        if remote.interfaces['signalstrings'] and signals2 then
          manager.preloadstring = remote.call('signalstrings','signals_to_string',signals2,true)
    
          local a = get_signal_from_set(knownsignals.white,signals2)
          if a > 0 and a <= 256 then
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
      else
        if game.active_mods["stringy-train-stop"] then
          local sigsched = get_signal_from_set(knownsignals.schedule,signals1)
          if sigsched > 0 then
            if not manager.schedule then manager.schedule = {} end
            local schedule = remote.call("stringy-train-stop", "parseScheduleEntry", signals1, manager.ent.surface)
            if schedule.name == "" then
              manager.schedule[sigsched] = {}
            else
              manager.schedule[sigsched] = schedule
            end
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
            ArtilleryOrder(manager,signals1,signals2,r.flare)
          end
        end
      end
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

local function onBuilt(event)
  local ent = event.created_entity
  if ent.name == "conman" then

    ent.set_recipe("conman-process")
    ent.active = false
    ent.operable = false

    local cc1 = CreateControl(ent, {x=ent.position.x-1,y=ent.position.y+1.5})
    local cc2 = CreateControl(ent, {x=ent.position.x+1,y=ent.position.y+1.5})

    if not global.managers then global.managers = {} end
    global.managers[ent.unit_number]={ent=ent, cc1 = cc1, cc2 = cc2}

  end
end

function reindex_rocks()
  local rocks={}
  
  for name,entproto in pairs(game.entity_prototypes) do
    if entproto.count_as_rock_for_filtered_deconstruction  then
      rocks[#rocks+1] = name
    end
  end
 
  global.deconrocks = rocks
end

function reindex_remotes()
 local artyremotes={}

 for name,itemproto in pairs(game.item_prototypes) do
   if itemproto.type == "capsule" and itemproto.capsule_action.type == "artillery-remote" then
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
      onBuilt({created_entity=entity})
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
script.on_event(defines.events.on_built_entity, onBuilt)
script.on_event(defines.events.on_robot_built_entity, onBuilt)

No_Profiler_Commands = true
local ProfilerLoaded,Profiler = pcall(require,'__profiler__/profiler.lua')
if not ProfilerLoaded then Profiler=nil end

remote.add_interface('conman',{
  --TODO: call to register items for custom decoding into ghost tags?

  read_preload_string = function(manager_id)
    return global.managers[manager_id] and global.managers[manager_id].preloadstring
  end,
  read_preload_color = function(manager_id)
    return global.managers[manager_id] and global.managers[manager_id].preloadstring
  end,
  
  set_preload_string = function(manager_id,str)
    if global.managers[manager_id] then
      global.managers[manager_id].preloadstring = str
    end
  end,
  set_preload_color = function(manager_id,color)
    if global.managers[manager_id] then
      global.managers[manager_id].preloadstring = color
    end
  end,
  
  hasProfiler = function() 
    return Profiler ~= nil 
  end,
  startProfile = function()
    if Profiler then Profiler.Start() end
  end,
  stopProfile = function()
    if Profiler then Profiler.Stop() end
  end,
})
