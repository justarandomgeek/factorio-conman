local function ReadPosition(signet,secondary,offset)
  if not offset then offset=0.5 end
  if not secondary then
    return {
      x = signet.get_signal({name="signal-X",type="virtual"})+offset,
      y = signet.get_signal({name="signal-Y",type="virtual"})+offset
    }
  else
    return {
      x = signet.get_signal({name="signal-U",type="virtual"})+offset,
      y = signet.get_signal({name="signal-V",type="virtual"})+offset
    }
  end
end

local function ReadBoundingBox(signet)
  -- adjust offests to make *inclusive* selection
  return {ReadPosition(signet,false,0),ReadPosition(signet,true,1)}
end

local function ReadFilters(signet,count)
  local filters = {}
  if signet.signals and #signet.signals > 0 then
    for i,s in pairs(signet.signals) do
      if s.signal.type == "item" then
        filters[#filters+1]={index = #filters+1, name = s.signal.name, count = s.count}
        if count and #filters==count then break end
      end
    end
  end
  return filters
end

local function ReadItems(signet,count)
  local items = {}
  if signet.signals and #signet.signals > 0 then
    for i,s in pairs(signet.signals) do
      if s.signal.type == "item" then
        items[s.signal.name] = s.count
        if count and #items==count then break end
      end
    end
  end
  return items
end

local function ReadSignalList(signet)
  local signals = {}
  for i=0,31 do
    for _,sig in pairs(signet.signals) do
      local sigbit = bit32.extract(sig.count,i)
      if sigbit==1 then
        signals[i+1] = sig.signal
        break
      end
    end
  end
  return signals
end

local function ConstructionOrder(manager,signet1,signet2)
  local createorder = {
    name='entity-ghost',
    position = ReadPosition(signet1),
    force = manager.ent.force,
    direction = signet1.get_signal({name="signal-D",type="virtual"}),
  }
  local usecc2items = true

  -- only set bar if it's non-zero, else chests are disabled by default.
  local bar = signet1.get_signal({name="signal-B",type="virtual"})
  if bar > 0 then createorder.bar = bar end

  for _,signal in pairs(signet1.signals) do
    if signal.signal.type == "item" and signal.signal.name ~= "construction-robot" then
      local itemproto = game.item_prototypes[signal.signal.name]
      local entproto = itemproto.place_result

      --TODO: tiles?
      if entproto then
        createorder.inner_name = entproto.name

        --set recipe if recipeid lib available
        if entproto.type == "assembling-machine" then
          if remote.interfaces['recipeid'] then
            createorder.recipe = remote.call('recipeid','map_recipe', signet1.get_signal({name="signal-R",type="virtual"}))
          end
        elseif entproto.type == "inserter" then
          --TODO: limit filter count
          createorder.filters = ReadFilters(signet2)
          usecc2items=false
        elseif entproto.type == "logistic-container" then
          --TODO: limit filter count
          createorder.request_filters = ReadFilters(signet2)
          usecc2items=false

        end

        break -- once we're found one, get out of the loop, so we don't build multiple things.
      end
    end
  end

  if createorder.inner_name then
    --game.print(serpent.block(createorder))
    local ghost =  manager.ent.surface.create_entity(createorder)

    if signet2 then
      if ghost.ghost_type == "constant-combinator" then
        local filters = {}
        if signet2.signals and #signet2.signals > 0 then
          for i,s in pairs(signet2.signals) do
            filters[#filters+1]={index = #filters+1, count = s.count, signal = s.signal}
          end
        end
        ghost.get_or_create_control_behavior().parameters={parameters=filters}

      elseif ghost.ghost_type == "arithmetic-combinator" then
        local siglist = ReadSignalList(signet2)

        --TODO: this doesn't work
        --local params = {
        --  first_signal = siglist[1],
        --  second_signal = siglist[2],
        --  constant = signet1.get_signal({name="signal-K",type="virtual"}),
        --  operation = "+",
        --  output_signal = siglist[3],
        --  }
        --game.print(serpent.block(params))
        --ghost.get_or_create_control_behavior().parameters=params

      elseif entproto.type == "decider-combinator" then
        local siglist = ReadSignalList(signet2)


      elseif usecc2items then
        ghost.item_requests = ReadItems(signet2)
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

local function DeployBlueprint(manager,signet1,signet2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)

  -- confirm it's a blueprint and is setup and such...
  local bp = inInv[1]
  if bp.valid and bp.valid_for_read and bp.is_blueprint_setup() then

    local force_build = signet1.get_signal({name="signal-F",type="virtual"})==1

    bp.build_blueprint{
      surface=manager.ent.surface,
      force=manager.ent.force,
      position=ReadPosition(signet1),
      direction = signet1.get_signal({name="signal-D",type="virtual"}),
      force_build= force_build,
    }
  end
end

local function CaptureBlueprint(manager,signet1,signet2)
  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  -- confirm it's a blueprint and is setup and such...
  local bp = inInv[1]
  if bp.valid and bp.valid_for_read then

    bp.create_blueprint{
      surface = manager.ent.surface,
      force = manager.ent.force,
      area = ReadBoundingBox(signet1),
      always_include_tiles = signet1.get_signal({name="signal-T",type="virtual"})==1,
    }

    if bp.is_blueprint_setup() then
      -- reset icons
      bp.blueprint_icons = bp.default_icons
    end

    -- set or clear label and color from cc2
    if remote.interfaces['signalstrings'] and signet2 and signet2.signals and #signet2.signals > 0  then
      bp.label = remote.call('signalstrings','signals_to_string',signet2.signals)

      local a = signet2.get_signal({name="signal-white",type="virtual"})
      if a > 0 and a <= 256 then
        local r = signet2.get_signal({name="signal-red",type="virtual"})
        local g = signet2.get_signal({name="signal-green",type="virtual"})
        local b = signet2.get_signal({name="signal-blue",type="virtual"})

        bp.label_color = { r=r/256, g=g/256, b=b/256, a=a/256 }
      end

    else
      bp.label = ''
      bp.label_color = { r=1, g=1, b=1, a=1 }
    end
  end
end

local function ConnectWire(manager,signet1,signet2,color,disconnect)
  local z = signet1.get_signal({name="signal-Z",type="virtual"})
  if not (z>0) then z=1 end

  local w = signet1.get_signal({name="signal-W",type="virtual"})
  if not (w>0) then w=1 end

  local ent1 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signet1)}[1]
  local ent2 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signet1,true)}[1]

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

local function ReportBlueprint(manager,signet1,signet2)
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
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.r*256,signal={name="signal-red",type="virtual"}}
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.g*256,signal={name="signal-green",type="virtual"}}
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.b*256,signal={name="signal-blue",type="virtual"}}
      outsignals[#outsignals+1]={index=#outsignals+1,count=bp.label_color.a*256,signal={name="signal-white",type="virtual"}}
    end

    -- add BoM signals
    for k,v in pairs(bp.cost_to_build) do
      outsignals[#outsignals+1]={index=#outsignals+1,count=v,signal={name=k,type="item"}}
    end
  end
  manager.cc2.get_or_create_control_behavior().parameters={parameters=outsignals}
  manager.clearcc2 = true
end

local function DeconstructionOrder(manager,signet1,signet2,cancel)
  local area = ReadBoundingBox(signet1)

  if not signet2 or not signet2.signals or #signet2.signals==0 then
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
    for _,signal in pairs(signet2.signals) do
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

local function DeliveryOrder(manager,signet1,signet2)

  local ent = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position=ReadPosition(signet1)}[1]
  if not (ent and ent.valid) then return end

  if signet2 and signet2.signals and #signet2.signals>0 then
    local items = {}
    for _,signal in pairs(signet2.signals) do
      if signal.signal.type == "item" then
        items[#items+1]={
          item=signal.signal.name,
          count=signal.count,
        }
      end
    end
    if #items > 0 then
      if ent.name == "entity-ghost" then
        -- just set the ghost requests
        -- TODO: probably ought to merge these?
        ent.item_requests = items
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

local function onTickManager(manager)
  if manager.clearcc2 then
    manager.clearcc2 = nil
    manager.cc2.get_or_create_control_behavior().parameters=nil
  end

  -- read cc1 signals. Only uses one wire, red if both connected.
  local signet1 = manager.cc1.get_circuit_network(defines.wire_type.red) or manager.cc1.get_circuit_network(defines.wire_type.green)
  if signet1 and signet1.signals and #signet1.signals > 0 then
    local signet2 = manager.cc2.get_circuit_network(defines.wire_type.red) or manager.cc2.get_circuit_network(defines.wire_type.green)

    local bpsig = signet1.get_signal({name="blueprint",type="item"})
    if bpsig ~= 0 then
      if bpsig == -1 then
        -- transfer blueprint to output
        EjectBlueprint(manager)

      elseif bpsig == 1 then
        -- deploy blueprint at XY
        DeployBlueprint(manager,signet1,signet2)

      elseif bpsig == 2 then
        -- capture blueprint from XYWH
        CaptureBlueprint(manager,signet1,signet2)

      elseif bpsig == 3 then
        ReportBlueprint(manager,signet1,signet2)
      end
    else

      if signet1.get_signal({name="construction-robot",type="item"}) == 1 then
        -- check for conbot=1, build a thing
        ConstructionOrder(manager,signet1,signet2)
      elseif signet1.get_signal({name="logistic-robot",type="item"}) == 1 then
        DeliveryOrder(manager,signet1,signet2)

      elseif signet1.get_signal({name="deconstruction-planner",type="item"}) == 1 then
        -- redprint=1, decon orders
        DeconstructionOrder(manager,signet1,signet2)
      elseif signet1.get_signal({name="deconstruction-planner",type="item"}) == -1 then
        -- redprint=-1, cancel decon orders
        DeconstructionOrder(manager,signet1,signet2,true)

      elseif signet1.get_signal({name="red-wire",type="item"}) == 1 then
        ConnectWire(manager,signet1,signet2,defines.wire_type.red)
      elseif signet1.get_signal({name="green-wire",type="item"}) == 1 then
        ConnectWire(manager,signet1,signet2,defines.wire_type.green)
      elseif signet1.get_signal({name="copper-cable",type="item"}) == 1 then
        ConnectWire(manager,signet1,signet2)
      elseif signet1.get_signal({name="red-wire",type="item"}) == -1 then
        ConnectWire(manager,signet1,signet2,defines.wire_type.red,true)
      elseif signet1.get_signal({name="green-wire",type="item"}) == -1 then
        ConnectWire(manager,signet1,signet2,defines.wire_type.green,true)
      elseif signet1.get_signal({name="copper-cable",type="item"}) == -1 then
        ConnectWire(manager,signet1,signet2,nil,true)
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

    ent.recipe = "conman-process"
    ent.active = false
    ent.operable = false

    local cc1 = CreateControl(ent, {x=ent.position.x-1,y=ent.position.y+1.5})
    local cc2 = CreateControl(ent, {x=ent.position.x+1,y=ent.position.y+1.5})

    if not global.managers then global.managers = {} end
    global.managers[ent.unit_number]={ent=ent, cc1 = cc1, cc2 = cc2}

  end
end

script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_built_entity, onBuilt)
script.on_event(defines.events.on_robot_built_entity, onBuilt)

remote.add_interface('conman',{
  --TODO: call to register signals for ghost proxies??
})
