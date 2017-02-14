local function ConstructionOrder(manager,signet1,signet2)
  local createorder = {
    name='entity-ghost',
    position = {
      x = signet1.get_signal({name="signal-X",type="virtual"}),
      y = signet1.get_signal({name="signal-Y",type="virtual"})
    },
    force = manager.ent.force,
    direction = signet1.get_signal({name="signal-D",type="virtual"}),
  }

  -- only set bar if it's non-zero, else chests are disabled by default.
  local bar = signet1.get_signal({name="signal-B",type="virtual"})
  if bar > 0 then createorder.bar = bar end

  for _,signal in pairs(signet1.signals) do
    if signal.signal.type == "item" and signal.signal.name ~= "construction-robot" then
      local itemproto = game.item_prototypes[signal.signal.name]
      local entproto = itemproto.place_result
      --TODO: tiles? trains? other mods?
      if entproto then
        createorder.inner_name = entproto.name

        --set recipe if recipeid lib available
        if entproto.type == "assembling-machine" and remote.interfaces['recipeid'] then
          createorder.recipe = remote.call('recipeid','map_recipe', signet1.get_signal({name="signal-R",type="virtual"}))
        end

        if entproto.type == "inserter" then
          -- TODO: inserter filters & conditions from cc2
          -- filters=1,
        end

        --TODO: other entity-specific config from cc1 or cc2
        break
      end
    end
  end

  if createorder.inner_name then
    local ghost =  manager.ent.surface.create_entity(createorder)

    if ghost.ghost_name == "constant-combinator" and signet2 then
      local filters = {}
      for i,s in pairs(signet2.signals) do
        filters[#filters+1]={index = #filters+1, count = s.count, signal = s.signal}
      end
      ghost.get_or_create_control_behavior().parameters={parameters=filters}
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

    local x = signet1.get_signal({name="signal-X",type="virtual"})
    local y = signet1.get_signal({name="signal-Y",type="virtual"})

    local force_build = signet1.get_signal({name="signal-F",type="virtual"})==1

    bp.build_blueprint{
      surface=manager.ent.surface,
      force=manager.ent.force,
      position={x=x,y=y},
      direction = signet1.get_signal({name="signal-D",type="virtual"}),
      force_build= force_build,
    }
  end
end

local function CaptureBlueprint(manager,signet1,signet2)
  local x = signet1.get_signal({name="signal-X",type="virtual"})
  local y = signet1.get_signal({name="signal-Y",type="virtual"})
  local w = signet1.get_signal({name="signal-W",type="virtual"})
  local h = signet1.get_signal({name="signal-H",type="virtual"})

  local inInv = manager.ent.get_inventory(defines.inventory.assembling_machine_input)
  -- confirm it's a blueprint and is setup and such...
  local bp = inInv[1]
  if bp.valid and bp.valid_for_read then

    bp.create_blueprint{
      surface = manager.ent.surface,
      force = manager.ent.force,
      area = {{x,y},{x+w-0.5,y+h-0.5}},
      always_include_tiles = signet1.get_signal({name="signal-T",type="virtual"})==1,
    }

    if bp.is_blueprint_setup() then
      -- reset icons
      bp.blueprint_icons = bp.default_icons
    end

    -- set or clear label and color from cc2
    if remote.interfaces['signalstrings'] and signet2 then
      bp.label = remote.call('signalstrings','signals_to_string',signet2.signals)

      local a = signet2.get_signal({name="signal-white",type="virtual"})
      if a > 0 and a <= 100 then
        local r = signet2.get_signal({name="signal-red",type="virtual"})
        local g = signet2.get_signal({name="signal-green",type="virtual"})
        local b = signet2.get_signal({name="signal-blue",type="virtual"})

        bp.label_color = { r=r/256, g=g/256, b=b/256, a=a/256 }
      end

    else
      bp.label = ''
      bp.label_color = nil
    end
  end
end

local function ConnectWire(manager,signet1,signet2,color,disconnect)
  local x = signet1.get_signal({name="signal-X",type="virtual"})
  local y = signet1.get_signal({name="signal-Y",type="virtual"})
  local z = signet1.get_signal({name="signal-Z",type="virtual"})
  if not (z>0) then z=1 end

  local u = signet1.get_signal({name="signal-U",type="virtual"})
  local v = signet1.get_signal({name="signal-V",type="virtual"})
  local w = signet1.get_signal({name="signal-W",type="virtual"})
  if not (w>0) then w=1 end

  local ent1 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position={x=x+0.5,y=y+0.5}}[1]
  local ent2 = manager.ent.surface.find_entities_filtered{force=manager.ent.force,position={x=u+0.5,y=v+0.5}}[1]

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
  local x = signet1.get_signal({name="signal-X",type="virtual"})
  local y = signet1.get_signal({name="signal-Y",type="virtual"})
  local w = signet1.get_signal({name="signal-W",type="virtual"})
  local h = signet1.get_signal({name="signal-H",type="virtual"})

  local area = {{x,y},{x+w-0.5,y+h-0.5}}

  if not signet2 or #signet2.signals==0 then
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
        local entname = game.item_prototypes[signal.signal.name].place_result.name
        if entname then
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

local function onTickManager(manager)
  if manager.clearcc2 then
    manager.clearcc2 = nil
    manager.cc2.get_or_create_control_behavior().parameters=nil
  end

  -- read cc1 signals. Only uses one wire, red if both connected.
  local signet1 = manager.cc1.get_circuit_network(defines.wire_type.red) or manager.cc1.get_circuit_network(defines.wire_type.green)
  if signet1 and #signet1.signals > 0 then
    local signet2 = manager.cc2.get_circuit_network(defines.wire_type.red) or manager.cc2.get_circuit_network(defines.wire_type.green)

    local bpsig = signet1.get_signal({name="blueprint",type="item"})

    if signet1.get_signal({name="construction-robot",type="item"}) == 1 then
      -- check for conbot=1, build a thing
      ConstructionOrder(manager,signet1,signet2)

    elseif bpsig == -1 then
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

local function onBuilt(event)
  local ent = event.created_entity
  if ent.name == "conman" then

    ent.recipe = "conman-process"
    ent.active = false
    ent.operable = false

    --TODO: find&revive ghosts like dynamic assemblers do
    local cc1 = ent.surface.create_entity{
      name='conman-control',
      position={x=ent.position.x-1,y=ent.position.y+1},
      force=ent.force
    }
    cc1.operable=false
    cc1.minable=false
    cc1.destructible=false

    local cc2 = ent.surface.create_entity{
      name='conman-control',
      position={x=ent.position.x+1,y=ent.position.y+1},
      force=ent.force
    }
    cc2.operable=false
    cc2.minable=false
    cc2.destructible=false

    if not global.managers then global.managers = {} end
    global.managers[ent.unit_number]={ent=ent, cc1 = cc1, cc2 = cc2}

  end
end

local function onPaste(event)
  local ent = event.destination
  if ent.name == "conman" then
    --TODO: do i need to do anything with paste here? or for CCs
  end
end

script.on_event(defines.events.on_tick, onTick)
script.on_event(defines.events.on_built_entity, onBuilt)
script.on_event(defines.events.on_robot_built_entity, onBuilt)
script.on_event(defines.events.on_entity_settings_pasted,onPaste)

remote.add_interface('conman',{
  --TODO: call to register signals for ghost proxies
})
