function get_signal_from_set(signal,set)
  for _,sig in pairs(set) do
    if sig.signal.type == signal.type and sig.signal.name == signal.name then
      return sig.count
    end
  end
  return 0
end

-- pre-built signal tables to save loads of table/string constructions
local knownsignals = {
  B = {name="signal-B",type="virtual"}, -- bar
  D = {name="signal-D",type="virtual"}, -- direction
  F = {name="signal-F",type="virtual"}, -- force build blueprint
                                        -- combinator "flag" (=1) output
  J = {name="signal-J",type="virtual"}, -- combinator first constant
  K = {name="signal-K",type="virtual"}, -- combinator second constant
  O = {name="signal-O",type="virtual"}, -- combinator operation
  R = {name="signal-R",type="virtual"}, -- recipeid (with recipeid mod)
  S = {name="signal-S",type="virtual"}, -- combinator special signal mode
  T = {name="signal-T",type="virtual"}, -- captured blueprint incldues tiles

  U = {name="signal-U",type="virtual"}, -- X2
  V = {name="signal-V",type="virtual"}, -- Y2
  W = {name="signal-W",type="virtual"}, -- wire connection select for XY2
  X = {name="signal-X",type="virtual"}, -- X1
  Y = {name="signal-Y",type="virtual"}, -- Y1
  Z = {name="signal-Z",type="virtual"}, -- wire connection select for XY1

  white = {name="signal-white",type="virtual"},
  red = {name="signal-red",type="virtual"},
  green = {name="signal-green",type="virtual"},
  blue = {name="signal-blue",type="virtual"},

  blueprint = {name="blueprint",type="item"},
  redprint = {name="deconstruction-planner",type="item"},
  conbot = {name="construction-robot",type="item"},
  logbot = {name="logistic-robot",type="item"},

  redwire = {name="red-wire",type="item"},
  greenwire = {name="green-wire",type="item"},
  coppercable = {name="copper-cable",type="item"},

  -- stringy train stops defines this
  schedule = {name="signal-schedule",type="virtual"},
}


local function ReadPosition(signals,secondary,offset)
  if not offset then offset=0.5 end
  if not secondary then
    return {
      x = get_signal_from_set(knownsignals.X,signals)+offset,
      y = get_signal_from_set(knownsignals.Y,signals)+offset
    }
  else
    return {
      x = get_signal_from_set(knownsignals.U,signals)+offset,
      y = get_signal_from_set(knownsignals.V,signals)+offset
    }
  end
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

local function ReadSignalList(signals)
  local selected = {}
  for i=0,31 do
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

local function ConstructionOrder(manager,signals1,signals2)
  local createorder = {
    name='entity-ghost',
    position = ReadPosition(signals1),
    force = manager.ent.force,
    expires = false,
    direction = get_signal_from_set(knownsignals.D,signals1),
  }
  local usecc2items = true

  -- only set bar if it's non-zero, else chests are disabled by default.
  local bar = get_signal_from_set(knownsignals.B,signals1)
  if bar > 0 then createorder.bar = bar end

  for _,signal in pairs(signals1) do
    if signal.signal.type == "item" and signal.signal.name ~= "construction-robot" then
      local itemproto = game.item_prototypes[signal.signal.name]
      local entproto = itemproto.place_result
      local tileresult = itemproto.place_as_tile_result

      if entproto then
        createorder.inner_name = entproto.name

        --set recipe if recipeid lib available
        if entproto.type == "assembling-machine" then
          if remote.interfaces['recipeid'] then
            createorder.recipe = remote.call('recipeid','map_recipe', get_signal_from_set(knownsignals.R,signals1))
          end
        elseif entproto.type == "inserter" then
          createorder.filters = ReadFilters(signals2, entproto.filter_count)
          usecc2items=false
        elseif entproto.type == "logistic-container" then
          createorder.request_filters = ReadFilters(signals2, entproto.filter_count)
          usecc2items=false
        elseif entproto.type == "cargo-wagon" then

          createorder.inventory = {
            bar = createorder.bar,
            --TODO: read a scale multiplier from signals1... F? S?
            filters = ReadInventoryFilters(signals2, entproto.get_inventory_size(defines.inventory.cargo_wagon))
          }
          createorder.bar = nil
          usecc2items=false
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
    --game.print(serpent.block(createorder))
    local ghost =  manager.ent.surface.create_entity(createorder)

    if ghost.name == "entity-ghost" then
      if ghost.ghost_type == "constant-combinator" then
        local filters = {}
        if signals2 then
          for i,s in pairs(signals2) do
            filters[#filters+1]={index = #filters+1, count = s.count, signal = s.signal}
          end
        end
        ghost.get_or_create_control_behavior().parameters={parameters=filters}

      elseif ghost.ghost_type == "arithmetic-combinator" then
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

        ghost.get_or_create_control_behavior().parameters={parameters = {
          first_signal = siglist[1],
          second_signal = siglist[2],
          first_constant = get_signal_from_set(knownsignals.J,signals1),
          second_constant = get_signal_from_set(knownsignals.K,signals1),
          operation = arithop[get_signal_from_set(knownsignals.O,signals1)] or "*",
          output_signal = siglist[3],
          }}

      elseif ghost.ghost_type == "decider-combinator" then
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

        ghost.get_or_create_control_behavior().parameters={parameters = {
          first_signal = siglist[1],
          second_signal = siglist[2],
          constant = get_signal_from_set(knownsignals.K,signals1),
          comparator =  deciderop[get_signal_from_set(knownsignals.O,signals1)] or "<",
          output_signal = siglist[3],
          copy_count_from_input = get_signal_from_set(knownsignals.F,signals1) == 0,
          }}


      elseif usecc2items then
        if signals2 then
          ghost.item_requests = ReadItems(signals2)
        end
      end
    end
  end
end

local function EjectBlueprint(manager)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  local outInv = manager.ent.get_inventory(defines.inventory.assembling_machine_output)
  outInv[1].set_stack(inInv[1])
  inInv[1].clear()
end

local function DeployBlueprint(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)

  -- confirm it's a blueprint and is setup and such...
  local bp = inInv[1]
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
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  -- confirm it's a blueprint and is setup and such...
  local bp = inInv[1]
  if bp.valid and bp.valid_for_read then

    bp.create_blueprint{
      surface = manager.ent.surface,
      force = manager.ent.force,
      area = ReadBoundingBox(signals1),
      always_include_tiles = get_signal_from_set(knownsignals.T,signals1)==1,
    }

    if bp.is_blueprint_setup() then
      -- reset icons
      bp.blueprint_icons = bp.default_icons
    end

    -- set or clear label and color from cc2
    if remote.interfaces['signalstrings'] and signals2 then
      bp.label = remote.call('signalstrings','signals_to_string',signals2)

      local a = get_signal_from_set(knownsignals.white,signals2)
      if a > 0 and a <= 256 then
        local r = get_signal_from_set(knownsignals.red,signals2)
        local g = get_signal_from_set(knownsignals.green,signals2)
        local b = get_signal_from_set(knownsignals.blue,signals2)

        bp.label_color = { r=r/256, g=g/256, b=b/256, a=a/256 }
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

local function ReportBlueprint(manager,signals1,signals2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  -- confirm it's a blueprint and is setup and such...
  local bp = inInv[1]
  local outsignals = {}
  if bp.valid and bp.valid_for_read then
    if bp.label and remote.interfaces['signalstrings'] then
      -- create label signals
      outsignals = remote.call('signalstrings','string_to_signals', bp.label)
    end

    -- add color signals
    if bp.label_color then
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.r*256,signal=knownsignals.red}
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.g*256,signal=knownsignals.green}
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.b*256,signal=knownsignals.blue}
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.a*256,signal=knownsignals.white}
    end

    -- add BoM signals
    for k,v in pairs(bp.cost_to_build) do
      outsignals[#outsignals+1]={index=#outsignals+1,count=v,signal={name=k,type="item"}}
    end
  end
  manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
  manager.clearcc2 = true
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
            name = 'stone-rock', area = area}) do

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


local function onTickManager(manager)
  if manager.clearcc2 then
    manager.clearcc2 = nil
    manager.cc2.get_or_create_control_behavior().parameters=nil
  end

  local signals1 = manager.cc1.get_merged_signals()
  if signals1 then
    local signals2 = manager.cc2.get_merged_signals()

    local bpsig = get_signal_from_set(knownsignals.blueprint,signals1)
    if bpsig ~= 0 then
      if bpsig == -1 then
        -- transfer blueprint to output
        EjectBlueprint(manager)

      elseif bpsig == 1 then
        -- deploy blueprint at XY
        DeployBlueprint(manager,signals1,signals2)

      elseif bpsig == 2 then
        -- capture blueprint from XYWH
        CaptureBlueprint(manager,signals1,signals2)

      elseif bpsig == 3 then
        ReportBlueprint(manager,signals1,signals2)
      end
    else

      if get_signal_from_set(knownsignals.conbot,signals1) == 1 then
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
      else
        if game.active_mods["stringy-train-stop"] then
          local sigsched = get_signal_from_set(knownsignals.schedule,signals1)
          if sigsched > 0 then
            if not manager.schedule then manager.schedule = {} end
            local schedule = remote.call("stringy-train-stop", "parseScheduleEntry", signals1)
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
        for _,remote in pairs(global.remotes) do
          if get_signal_from_set(remote.signal,signals1) == 1 then
            ArtilleryOrder(manager,signals1,signals2,remote.flare)
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

function reindex_remotes()
 local remotes={}

 for name,itemproto in pairs(game.item_prototypes) do
   if itemproto.type == "capsule" and itemproto.capsule_action.type == "artillery-remote" then
     remotes[name] = { signal = {name=name,type="item"}, flare = itemproto.capsule_action.flare }
   end
 end

 global.remotes = remotes
end

script.on_init(function()
  -- Index recipes for new install
  reindex_remotes()
end
)

script.on_configuration_changed(function(data)
  -- when any mods change, reindex recipes
  reindex_remotes()
end
)


script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_built_entity, onBuilt)
script.on_event(defines.events.on_robot_built_entity, onBuilt)

remote.add_interface('conman',{
  --TODO: call to register signals for ghost proxies??
})
