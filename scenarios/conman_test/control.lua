CoverageLoaded,Coverage = pcall(require,'__coverage__/coverage.lua')
if CoverageLoaded then
    Coverage.LevelPath("conman","scenarios/conman_test/")
else
    Coverage=nil
end
CoverageLoaded = nil



local knownsignals = require("__conman__/knownsignals.lua")

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

function expect_signals(expectedsignals,expectedvalues,gotsignals,allowextra)
    local gotvalues = get_signals_filtered(expectedsignals,gotsignals)
    local gotsize = table_size(gotvalues)
    local expectedsize = table_size(expectedvalues)
    if (gotsize < expectedsize) or (not allowextra and gotsize > expectedsize) then
        return false 
    end
    for k,v in pairs(expectedvalues) do
        if gotvalues[k] ~= v then return false end
    end
    return true
end

local tests = {
    ["profilestart"] ={
        prepare = function()
            if remote.call("conman","hasProfiler") then
                if not global.profilecount then
                    remote.call("conman","startProfile")
                end
            end
        end,
        cc1 = {

        },
        cc2 = {

        },
        verify = function()
            return true
        end
    },
    ["container"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "wooden-chest"}, count = 1},
            {signal = knownsignals.B, count = 3},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 42},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}
            
            if irp and irp.item_requests["wooden-chest"] == 42 then
                irp.destroy()
            else
                return false
            end

            if ghost.get_inventory(defines.inventory.chest).getbar() == 4 then
                ghost.destroy()
            else
                return false
            end
            
            return true
        end
    },
    ["craftingmachine"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "assembling-machine-3"}, count = 1},
            {signal = knownsignals.R, count = -126192623}, -- "inserter"
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 42},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp and irp.item_requests["wooden-chest"] == 42 then
                irp.destroy()
            else
                return false
            end
            local recipe = ghost.get_recipe()
            if recipe and recipe.name == "inserter" then
                ghost.destroy()
            else
                return false
            end
            
            return true
        end
    },
    ["apchest"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "logistic-chest-active-provider"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 42},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp and irp.item_requests["wooden-chest"] == 42 then
                irp.destroy()
            else
                return false
            end
            
            ghost.destroy()
            
            return true
        end
    },
    ["stchest"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "logistic-chest-storage"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 1},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            if ghost.storage_filter and ghost.storage_filter.name == "wooden-chest" then
                ghost.destroy()
            else
                return false
            end
            
            return true
        end
    },
    ["ppchest"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "logistic-chest-passive-provider"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 42},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp and irp.item_requests["wooden-chest"] == 42 then
                irp.destroy()
            else
                return false
            end
            
            ghost.destroy()
            
            return true
        end
    },
    ["buchest"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "logistic-chest-buffer"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 42},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local req = ghost.get_request_slot(1)
            if req and req.name == "wooden-chest" and req.count == 42 then 
                ghost.destroy()
            else
                return false
            end
            
            return true
        end
    },
    ["rqchest"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "logistic-chest-requester"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = {type = "item", name = "wooden-chest"}, count = 42},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local req = ghost.get_request_slot(1)
            if req and req.name == "wooden-chest" and req.count == 42 then 
                ghost.destroy()
            else
                return false
            end
            
            return true
        end
    },
    ["rqchestcircuit"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "logistic-chest-requester"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.R, count = 1},
            {signal = knownsignals.S, count = 1},

        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if control and 
                control.circuit_mode_of_operation == defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests	and
                ghost.request_from_buffers
                then 
                ghost.destroy()
            else
                return false
            end
            return true
        end
    },
    ["constcomb"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "constant-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

        },
        cc2 = {
            {signal = knownsignals.A, count = 2},
            {signal = knownsignals.B, count = 3},
            {signal = knownsignals.blueprint, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            local sig = control.get_signal(1)
            if not (sig and sig.signal.name == "signal-A" and sig.count == 2) then return false end
            local sig = control.get_signal(2)
            if not (sig and sig.signal.name == "signal-B" and sig.count == 3) then return false end
            local sig = control.get_signal(3)
            if not (sig and sig.signal.name == "blueprint" and sig.count == 4) then return false end

            ghost.destroy()
            return true
        end
    },
    ["arithcomb"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "arithmetic-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 2},
            
        },
        cc2 = {
            {signal = knownsignals.A, count = 1},
            {signal = knownsignals.blueprint, count = 2},
            {signal = knownsignals.C, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_signal.name == "signal-A" and 
                control.parameters.parameters.second_signal.name == "blueprint" and
                control.parameters.parameters.output_signal.name == "signal-C" and
                control.parameters.parameters.operation == "/") then return false end

            ghost.destroy()
            return true
        end
    },
    ["arithcombeach"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "arithmetic-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 3},
            {signal = knownsignals.S, count = 2},
            
        },
        cc2 = {
            {signal = knownsignals.B, count = 2},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_signal.name == "signal-each" and 
                control.parameters.parameters.second_signal.name == "signal-B" and
                control.parameters.parameters.output_signal.name == "signal-each" and
                control.parameters.parameters.operation == "+") then return false end
                
            ghost.destroy()
            return true
        end
    },
    ["arithcombconst"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "arithmetic-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 4},
            {signal = knownsignals.J, count = 12},
            {signal = knownsignals.K, count = 34},
            
        },
        cc2 = {
            {signal = knownsignals.C, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_constant == 12 and 
                control.parameters.parameters.second_constant == 34 and
                control.parameters.parameters.output_signal.name == "signal-C" and
                control.parameters.parameters.operation == "-") then return false end

            ghost.destroy()
            return true
        end
    },
    ["decidcomb"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "decider-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 2},
            
        },
        cc2 = {
            {signal = knownsignals.A, count = 1},
            {signal = knownsignals.blueprint, count = 2},
            {signal = knownsignals.C, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_signal.name == "signal-A" and 
                control.parameters.parameters.second_signal.name == "blueprint" and
                control.parameters.parameters.output_signal.name == "signal-C" and
                control.parameters.parameters.comparator == ">") then return false end

            ghost.destroy()
            return true
        end
    },
    ["decidcombeach"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "decider-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 3},
            {signal = knownsignals.S, count = 2},
            
        },
        cc2 = {
            {signal = knownsignals.B, count = 2},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_signal.name == "signal-each" and 
                control.parameters.parameters.second_signal.name == "signal-B" and
                control.parameters.parameters.output_signal.name == "signal-each" and
                control.parameters.parameters.comparator == "=") then return false end
                
            ghost.destroy()
            return true
        end
    },
    ["decidcombevery"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "decider-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 4},
            {signal = knownsignals.S, count = 6},
            
        },
        cc2 = {
            {signal = knownsignals.B, count = 2},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_signal.name == "signal-everything" and 
                control.parameters.parameters.second_signal.name == "signal-B" and
                control.parameters.parameters.output_signal.name == "signal-everything" and
                control.parameters.parameters.comparator == "≥") then return false end
                
            ghost.destroy()
            return true
        end
    },
    ["decidcombanyconst"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "decider-combinator"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.O, count = 5},
            {signal = knownsignals.S, count = 3},
            {signal = knownsignals.K, count = 34},
            {signal = knownsignals.F, count = 1},
            
        },
        cc2 = {
            {signal = knownsignals.C, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            local control = ghost.get_or_create_control_behavior()
            if not control then return false end
            if not (control.parameters.parameters.first_signal.name == "signal-anything" and 
                control.parameters.parameters.constant == 34 and
                control.parameters.parameters.output_signal.name == "signal-C" and
                control.parameters.parameters.comparator == "≤" and 
                control.parameters.parameters.copy_count_from_input == false) then return false end

            ghost.destroy()
            return true
        end
    },
    ["splitter"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "express-splitter"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.I, count = 1},
            {signal = knownsignals.O, count = 2},
        },
        cc2 = {
            {signal = knownsignals.redwire, count = 1},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            if not (ghost.splitter_input_priority == "left" and
                ghost.splitter_output_priority == "right" and
                ghost.splitter_filter and ghost.splitter_filter.name == knownsignals.redwire.name) then return false end

            ghost.destroy()
            return true
        end
    },
    ["pump"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "pump"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.K, count = 42},
            {signal = knownsignals.O, count = 2},

        },
        cc2 = {
            {signal = knownsignals.A, count = 1},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end
            
            ghost.destroy()
            return true
        end
    },
    ["electric-mining-drill"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "electric-mining-drill"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.R, count = 2},

        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (control.circuit_read_resources and
                control.resource_read_mode == defines.control_behavior.mining_drill.resource_read_mode.entire_patch) then return false end
            
            ghost.destroy()
            return true
        end
    },
    ["train-stop"] = {
        prepare = function()
            remote.call("conman","set_preload_string",global.conman.unit_number,"TEST")
        end,
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "train-stop"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

            {signal = knownsignals.R, count = 1},
            {signal = knownsignals.T, count = 1},

            {signal = knownsignals.red, count = 255},
            {signal = knownsignals.green, count = 127},
            {signal = knownsignals.blue, count = 63},
            {signal = knownsignals.white, count = 255},

        },
        cc2 = {
            {signal = knownsignals.A, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            if ghost.backer_name ~= "TEST" then return false end

            local control = ghost.get_or_create_control_behavior()
            if not (control.send_to_train and control.read_from_train and control.read_stopped_train and
                control.stopped_train_signal.name == knownsignals.A.name) then return false end
            
            if not(
                math.floor(ghost.color.r*255) == 255 and 
                math.floor(ghost.color.g*255) == 127 and
                math.floor(ghost.color.b*255) ==  63 and
                math.floor(ghost.color.a*255) == 255 ) then return false end


            ghost.destroy()
            return true
        end
    },
    
    ["straight-rail"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "rail"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}
            if irp then
                return false
            end
            if not ghost.name=="straight-rail" then return false end
            ghost.destroy()
            return true
        end
    },
    ["curved-rail"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "rail"}, count = 2},
            {signal = knownsignals.X, count = -4},
            {signal = knownsignals.Y, count = -4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-4,-4})
            local irp 
            if not ghost then return false end
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}
            if irp then
                return false
            end
            if not ghost.name=="curved-rail" then return false end
            ghost.destroy()
            return true
        end
    },
    ["rail-signal"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "rail-signal"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

            {signal = knownsignals.R, count = 1},


        },
        cc2 = {
            {signal = knownsignals.A, count = 4},
            {signal = knownsignals.B, count = 8},
            {signal = knownsignals.C, count = 16},

        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (control.read_signal and
                control.red_signal.name == knownsignals.A.name and
                control.orange_signal.name == knownsignals.B.name and
                control.green_signal.name == knownsignals.C.name) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["rail-chain-signal"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "rail-chain-signal"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},

            {signal = knownsignals.R, count = 1},


        },
        cc2 = {
            {signal = knownsignals.A, count = 4},
            {signal = knownsignals.B, count = 8},
            {signal = knownsignals.C, count = 16},
            {signal = knownsignals.D, count = 32},

        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (
                control.red_signal.name == knownsignals.A.name and
                control.orange_signal.name == knownsignals.B.name and
                control.green_signal.name == knownsignals.C.name and
                control.blue_signal.name == knownsignals.D.name) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["wall"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "stone-wall"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.R, count = 1},
        },
        cc2 = {
            {signal = knownsignals.A, count = 4},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not ( control.read_sensor and
                control.output_signal.name == knownsignals.A.name) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["loader"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "express-loader"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            if not ( ghost.loader_type == "input") then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["underbelt"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "underground-belt"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.U, count = 1},
        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            if not ( ghost.belt_to_ground_type == "output") then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["inserter"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "filter-inserter"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.E, count = 1},
            {signal = knownsignals.O, count = 1},
            {signal = knownsignals.R, count = 2},
        },
        cc2 = {
            {signal = knownsignals.A, count = 1},
            {signal = knownsignals.B, count = 2},
            
            {signal = knownsignals.C, count = 4},

            {signal = knownsignals.redprint, count = 8},
            {signal = knownsignals.blueprint, count = 16},
            {signal = knownsignals.conbot, count = 32},
            {signal = knownsignals.logbot, count = 64},
            {signal = knownsignals.redwire, count = 128},

            {signal = knownsignals.greenwire, count = 256}, -- one too many to be discarded
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (
                control.circuit_condition.condition.first_signal.name == "signal-A" and 
                control.circuit_condition.condition.second_signal.name == "signal-B" and
                control.circuit_condition.condition.comparator == "<" and
                control.circuit_mode_of_operation == defines.control_behavior.inserter.circuit_mode_of_operation.enable_disable and
                control.circuit_read_hand_contents and
                control.circuit_hand_read_mode == defines.control_behavior.inserter.hand_read_mode.hold and
                control.circuit_set_stack_size and control.circuit_stack_control_signal.name == knownsignals.C.name and
                ghost.get_filter(1) == knownsignals.redprint.name and
                ghost.get_filter(2) == knownsignals.blueprint.name and
                ghost.get_filter(3) == knownsignals.conbot.name and
                ghost.get_filter(4) == knownsignals.logbot.name and
                ghost.get_filter(5) == knownsignals.redwire.name
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["insertercirc"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "stack-filter-inserter"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.B, count = 1},
            {signal = knownsignals.F, count = 1},
            {signal = knownsignals.I, count = 3},
        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (
                ghost.inserter_stack_size_override == 3 and
                control.circuit_mode_of_operation == defines.control_behavior.inserter.circuit_mode_of_operation.set_filters and
                ghost.inserter_filter_mode == "blacklist"
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["belt"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "transport-belt"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.R, count = 2},
        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not ( control.read_contents and 
                control.read_contents_mode == defines.control_behavior.transport_belt.content_read_mode.hold
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["lamp"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "small-lamp"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.C, count = 1},
            {signal = knownsignals.O, count = 1},
        },
        cc2 = {
            {signal = knownsignals.A, count = 1},
            {signal = knownsignals.B, count = 2},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not ( control.use_colors and 
                control.circuit_condition.condition.first_signal.name == "signal-A" and 
                control.circuit_condition.condition.second_signal.name == "signal-B" and
                control.circuit_condition.condition.comparator == "<"
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["speaker"] = {
        multifeed = {
            {
                cc1 = {
                    {signal = knownsignals.info, count = 1}, 
                },
                cc2string = "ALERT",
            },
            {
                cc1 = {
                    {signal = knownsignals.conbot, count = 1},
                    {signal = {type = "item", name = "programmable-speaker"}, count = 1},
                    {signal = knownsignals.X, count = -3},
                    {signal = knownsignals.Y, count = -3},
                    {signal = knownsignals.A, count = 1},
                    {signal = knownsignals.G, count = 1},
                    {signal = knownsignals.I, count = 3},
                    {signal = knownsignals.M, count = 1},
                    {signal = knownsignals.P, count = 1},
                    {signal = knownsignals.U, count = 42},
                    {signal = knownsignals.V, count = 1},
                },
                cc2 = {
                    {signal = knownsignals.A, count = 1},
                    {signal = knownsignals.B, count = 4},
                },
            },
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            
            local control = ghost.get_or_create_control_behavior()
            if not ( control.circuit_parameters.signal_value_is_pitch and
                control.circuit_parameters.instrument_id == 3 and
                control.circuit_condition.condition.first_signal.name == knownsignals.A.name and 
                ghost.alert_parameters.show_alert and
                ghost.alert_parameters.show_on_map and
                ghost.alert_parameters.icon_signal_id.name == knownsignals.B.name and
                ghost.alert_parameters.alert_message == "ALERT" and 
                ghost.parameters.playback_volume == 0.42 and 
                ghost.parameters.playback_globally and
                ghost.parameters.allow_polyphony
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["powerswitch"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "power-switch"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.C, count = 1},
            {signal = knownsignals.O, count = 1},
            {signal = knownsignals.S, count = 3},
        },
        cc2 = {
            {signal = knownsignals.B, count = 2},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (
                control.circuit_condition.condition.first_signal.name == "signal-anything" and 
                control.circuit_condition.condition.second_signal.name == "signal-B" and
                control.circuit_condition.condition.comparator == "<"
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["offshore-pump"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "offshore-pump"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
            {signal = knownsignals.C, count = 1},
            {signal = knownsignals.O, count = 1},
            {signal = knownsignals.S, count = 5},
        },
        cc2 = {
            {signal = knownsignals.B, count = 2},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (
                control.circuit_condition.condition.first_signal.name == "signal-everything" and 
                control.circuit_condition.condition.second_signal.name == "signal-B" and
                control.circuit_condition.condition.comparator == "<"
                ) then return false end
            
            
            ghost.destroy()
            return true
        end
    },
    ["roboport"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "roboport"}, count = 1},
            {signal = knownsignals.X, count = -4},
            {signal = knownsignals.Y, count = -4},

            {signal = knownsignals.R, count = 1},


        },
        cc2 = {
            {signal = knownsignals.A, count = 1},
            {signal = knownsignals.B, count = 2},
            {signal = knownsignals.C, count = 4},
            {signal = knownsignals.D, count = 8},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-3,-3})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (
                control.mode_of_operations == defines.control_behavior.roboport.circuit_mode_of_operation.read_robot_stats and
                control.available_logistic_output_signal.name == knownsignals.A.name and
                control.total_logistic_output_signal.name == knownsignals.B.name and
                control.available_construction_output_signal.name == knownsignals.C.name and
                control.total_construction_output_signal.name ==  knownsignals.D.name) then return false end
            
            ghost.destroy()
            return true
        end
    },
    ["accumulator"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "accumulator"}, count = 1},
            {signal = knownsignals.X, count = -4},
            {signal = knownsignals.Y, count = -4},
        },
        cc2 = {
            {signal = {type = "item", name = "accumulator"}, count = 1},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-3,-3})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp then
                return false
            end

            local control = ghost.get_or_create_control_behavior()
            if not (control.output_signal.name == "accumulator") then return false end
            
            ghost.destroy()
            return true
        end
    },
    ["tile"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "concrete"}, count = 1},
            {signal = knownsignals.X, count = -4},
            {signal = knownsignals.Y, count = -4},
        },
        cc2 = {
        },
        verify = function()
            local ghost = global.surface.find_entity('tile-ghost', {-3,-3})
            
            if not (ghost) then return false end
            
            ghost.destroy()
            return true
        end
    },
    ["rocket-silo"] = {
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "rocket-silo"}, count = 1},
            {signal = knownsignals.X, count = -6},
            {signal = knownsignals.Y, count = -6},
            {signal = knownsignals.A, count = 1},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-5,-5})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if irp or not ghost then
                return false
            end

            if not ghost.auto_launch then return false end
            
            ghost.destroy()
            return true
        end
    },
    
    ["cargo-wagon"] = {
        prepare = function()
            global.rails={
                global.surface.create_entity{name="straight-rail",position={-3,-1}},
                global.surface.create_entity{name="straight-rail",position={-3,-3}},
                global.surface.create_entity{name="straight-rail",position={-3,-5}},
                global.surface.create_entity{name="straight-rail",position={-3,-7}},
            }
        end,
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "cargo-wagon"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -4},

            {signal = knownsignals.B, count = 3},
            
            {signal = knownsignals.red, count = 255},
            {signal = knownsignals.green, count = 127},
            {signal = knownsignals.blue, count = 63},
            {signal = knownsignals.white, count = 255},

        },
        cc2 = {
            {signal = knownsignals.redwire, count = 0x40000001},
            {signal = knownsignals.greenwire, count = 2},
            {signal = knownsignals.coppercable, count = -0x80000000},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-3,-3})
            _,ghost = ghost.revive()
            
            if not(
                math.floor(ghost.color.r*255) == 255 and 
                math.floor(ghost.color.g*255) == 127 and
                math.floor(ghost.color.b*255) ==  63 and
                math.floor(ghost.color.a*255) == 255 ) then return false end

            local inv = ghost.get_inventory(defines.inventory.chest)

            if not (inv.getbar() == 4 and 
                inv.get_filter(1) == knownsignals.redwire.name and
                inv.get_filter(2) == knownsignals.greenwire.name and
                inv.get_filter(3) == nil and 
                inv.get_filter(31) == knownsignals.redwire.name and
                inv.get_filter(32) == knownsignals.coppercable.name and
                inv.get_filter(33) == knownsignals.coppercable.name and
                inv.get_filter(34) == knownsignals.coppercable.name and
                inv.get_filter(35) == knownsignals.coppercable.name and
                inv.get_filter(36) == knownsignals.coppercable.name and
                inv.get_filter(37) == knownsignals.coppercable.name and
                inv.get_filter(38) == knownsignals.coppercable.name and
                inv.get_filter(39) == knownsignals.coppercable.name
                ) then return false end
            ghost.destroy()

            for _,ent in pairs(global.rails) do ent.destroy() end
            global.rails = nil
            return true
        end
    },
    ["locomotive"] = {
        prepare = function()
            global.rails={
                global.surface.create_entity{name="straight-rail",position={-3,-1}},
                global.surface.create_entity{name="straight-rail",position={-3,-3}},
                global.surface.create_entity{name="straight-rail",position={-3,-5}},
                global.surface.create_entity{name="straight-rail",position={-3,-7}},
            }
        end,
        cc1 = {
            {signal = knownsignals.conbot, count = 1},
            {signal = {type = "item", name = "locomotive"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -4},
            
            {signal = knownsignals.red, count = 255},
            {signal = knownsignals.green, count = 127},
            {signal = knownsignals.blue, count = 63},
            {signal = knownsignals.white, count = 255},

        },
        cc2 = {
            {signal = knownsignals.redwire, count = 12},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-3,-3})
            local irp 
            _,ghost,irp = ghost.revive{return_item_request_proxy=true}

            if not(irp and irp.item_requests[knownsignals.redwire.name] == 12) then return false end
            irp.destroy()
            
            if not(
                math.floor(ghost.color.r*255) == 255 and 
                math.floor(ghost.color.g*255) == 127 and
                math.floor(ghost.color.b*255) ==  63 and
                math.floor(ghost.color.a*255) == 255 ) then return false end
            
            ghost.destroy()

            for _,ent in pairs(global.rails) do ent.destroy() end
            global.rails = nil
            return true
        end
    },

    ["schedule"] = {
        prepare = function()
            global.rails={
                global.surface.create_entity{name="straight-rail",position={-3,-1}},
                global.surface.create_entity{name="straight-rail",position={-3,-3}},
                global.surface.create_entity{name="straight-rail",position={-3,-5}},
                global.surface.create_entity{name="straight-rail",position={-3,-7}},
            }
            global.loco = global.surface.create_entity{name="locomotive",force="player",position={-3,-4}}
        end,
        multifeed = {
            {
                cc1string = "FOO",
                cc1 = {
                    {signal = knownsignals.schedule, count = 1},
                    {signal = {name="signal-wait-time",type="virtual"}, count = 123},
                },
            },
            {
                cc1string = "BAR",
                cc1 = {
                    {signal = knownsignals.schedule, count = 2},
                    {signal = {name="signal-wait-inactivity",type="virtual"}, count = 456},
                },
            },
            {
                cc1string = "[item=iron-ore]DROP",
                cc1 = {
                    {signal = knownsignals.schedule, count = 3},
                    {signal = {name="signal-stopname-richtext",type="virtual"}, count = 1},
                    {signal = {name="signal-wait-empty",type="virtual"}, count = 1},
                    {signal = {name="signal-wait-robots",type="virtual"}, count = 1},
                },
            },
            {
                cc1 = {
                    {signal = knownsignals.schedule, count = 4},
                    {signal = {name="signal-schedule-rail",type="virtual"}, count = 1},
                    {signal = knownsignals.X, count = -3},
                    {signal = knownsignals.Y, count = -1},
                    {signal = {name="signal-wait-full",type="virtual"}, count = 1},
                },
            },
            {
                cc1 = {
                    {signal = knownsignals.schedule, count = -1},
                    {signal = knownsignals.X, count = -3},
                    {signal = knownsignals.Y, count = -4},
                },
            },
        },
        verify = function()
            local schedule = global.loco.train.schedule

            if not (
                schedule and
                schedule.records[1].station == "FOO" and
                schedule.records[1].wait_conditions[1].type == "time" and schedule.records[1].wait_conditions[1].ticks == 123 and
                schedule.records[2].station == "BAR" and
                schedule.records[2].wait_conditions[1].type == "inactivity" and schedule.records[2].wait_conditions[1].ticks == 456 and
                schedule.records[3].station == "[item=iron-ore]DROP" and
                schedule.records[3].wait_conditions[1].type == "empty" and schedule.records[3].wait_conditions[2].type == "robots_inactive" and
                schedule.records[4].rail == global.rails[1] and 
                schedule.records[4].wait_conditions[1].type == "full"
            ) then return false end
            global.loco.destroy()
            global.loco = nil
            for _,ent in pairs(global.rails) do ent.destroy() end
            global.rails = nil
            return true
        end
    },

    ["irp"] = {
        prepare = function()
            global.chest=global.surface.create_entity{name="wooden-chest",force="player",position={-3.5,-3.5}}
        end,
        cc1 = {
            {signal = knownsignals.logbot, count = 1},
            {signal = knownsignals.X, count = -4},
            {signal = knownsignals.Y, count = -4},
        },
        cc2 = {
            {signal = knownsignals.redwire, count = 12},
        },
        verify = function()
            local irp = global.surface.find_entity('item-request-proxy', {-3.5,-3.5})
            
            if not(irp and irp.proxy_target == global.chest and irp.item_requests[knownsignals.redwire.name] == 12) then return false end
            irp.destroy()
            
            global.chest.destroy()
            global.chest = nil
            return true
        end
    },

    ["connectwires"] = {
        prepare = function()
            global.poles = {
                global.surface.create_entity{name="medium-electric-pole",force="player",position={-3.5,-3.5}},
                global.surface.create_entity{name="medium-electric-pole",force="player",position={-4.5,-3.5}},
            }
            global.poles[1].disconnect_neighbour()
        end,
        multifeed = {
            {
                cc1 = {
                    {signal = knownsignals.redwire, count = 1},
                    {signal = knownsignals.X, count = -4},
                    {signal = knownsignals.Y, count = -4},
                    {signal = knownsignals.U, count = -5},
                    {signal = knownsignals.V, count = -4},
                },
            },
            {
                cc1 = {
                    {signal = knownsignals.greenwire, count = 1},
                    {signal = knownsignals.X, count = -4},
                    {signal = knownsignals.Y, count = -4},
                    {signal = knownsignals.U, count = -5},
                    {signal = knownsignals.V, count = -4},
                },
            },
            {
                cc1 = {
                    {signal = knownsignals.coppercable, count = 1},
                    {signal = knownsignals.X, count = -4},
                    {signal = knownsignals.Y, count = -4},
                    {signal = knownsignals.U, count = -5},
                    {signal = knownsignals.V, count = -4},
                },
            },
        },
        verify = function()
            local neighbours = global.poles[1].neighbours
            if not (
                neighbours.copper[1] == global.poles[2] and
                neighbours.red[1] == global.poles[2] and
                neighbours.green[1] == global.poles[2]
                ) then return false end

            for _,ent in pairs(global.poles) do ent.destroy() end
            global.poles = nil
            return true
        end
    },
    ["disconnectwires"] = {
        prepare = function()
            global.poles = {
                global.surface.create_entity{name="medium-electric-pole",force="player",position={-3.5,-3.5}},
                global.surface.create_entity{name="medium-electric-pole",force="player",position={-4.5,-3.5}},
            }
            global.poles[1].disconnect_neighbour()
            global.poles[1].connect_neighbour(global.poles[2])
            global.poles[1].connect_neighbour{target_entity = global.poles[2], wire = defines.wire_type.red,}
            global.poles[1].connect_neighbour{target_entity = global.poles[2], wire = defines.wire_type.green,}
        end,
        multifeed = {
            {
                cc1 = {
                    {signal = knownsignals.redwire, count = -1},
                    {signal = knownsignals.X, count = -4},
                    {signal = knownsignals.Y, count = -4},
                    {signal = knownsignals.U, count = -5},
                    {signal = knownsignals.V, count = -4},
                },
            },
            {
                cc1 = {
                    {signal = knownsignals.greenwire, count = -1},
                    {signal = knownsignals.X, count = -4},
                    {signal = knownsignals.Y, count = -4},
                    {signal = knownsignals.U, count = -5},
                    {signal = knownsignals.V, count = -4},
                },
            },
            {
                cc1 = {
                    {signal = knownsignals.coppercable, count = -1},
                    {signal = knownsignals.X, count = -4},
                    {signal = knownsignals.Y, count = -4},
                    {signal = knownsignals.U, count = -5},
                    {signal = knownsignals.V, count = -4},
                },
            },
        },
        verify = function()
            local neighbours = global.poles[1].neighbours
            if not (
                #neighbours.copper == 0 and
                #neighbours.red == 0 and
                #neighbours.green == 0
                ) then return false end

            for _,ent in pairs(global.poles) do ent.destroy() end
            global.poles = nil
            return true
        end
    },

    ["artillery"] = {
        cc1 = {
            {signal = {type = "item", name = "artillery-targeting-remote"}, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
        },
        verify = function()
            local flare = global.surface.find_entity('artillery-flare', {-2.5,-2.5})
            if not flare then return false end
            
            flare.destroy()
            
            return true
        end
    },

    ["create"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].clear()
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -2},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            if not stack.valid_for_read then return false end
            
            stack.clear()
            
            return true
        end
    },
    ["createbook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[2].clear()
        end,
        cc1 = {
            {signal = knownsignals.blueprint_book, count = -2},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            if not stack.valid_for_read then return false end
            
            stack.clear()
            
            return true
        end
    },
    ["createinbook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[2].set_stack("blueprint-book")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -2},
            {signal = knownsignals.blueprint_book, count = 1},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            if not stack.valid_for_read then return false end
            local bp = stack.get_inventory(defines.inventory.item_main)[1]
            if not bp.valid_for_read then return false end
            stack.clear()
            return true
        end
    },

    ["destroy"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].set_stack("blueprint")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -3},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            if stack.valid_for_read then return false end
            return true
        end
    },
    ["destroybook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[2].set_stack("blueprint-book")
        end,
        cc1 = {
            {signal = knownsignals.blueprint_book, count = -3},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            if stack.valid_for_read then return false end
            return true
        end
    },
    ["destroyinbook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].clear()
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            book.set_stack("blueprint-book")
            book.get_inventory(defines.inventory.item_main).insert{name="blueprint",count=1}
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -3},
            {signal = knownsignals.blueprint_book, count = 1},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            if not stack.valid_for_read then return false end
            local bp = stack.get_inventory(defines.inventory.item_main)[1]
            if bp.valid_for_read then return false end
            return true
        end
    },


    ["takefrombook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].clear()
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            book.set_stack("blueprint-book")
            book.get_inventory(defines.inventory.item_main).insert{name="blueprint",count=1}
            
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -4},
            {signal = knownsignals.blueprint_book, count = 1},
        },
        verify = function()
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            if not bp.valid_for_read then return false end
            bp.clear()
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            if book.get_inventory(defines.inventory.item_main).get_item_count() ~= 0 then return false end
            book.clear()
            return true
        end
    },
    ["inserttobook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].set_stack("blueprint")
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[2].set_stack("blueprint-book")            
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -5},
            {signal = knownsignals.blueprint_book, count = 1},
        },
        verify = function()
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            if bp.valid_for_read then return false end            
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            if book.get_inventory(defines.inventory.item_main).get_item_count() ~= 1 then return false end
            book.clear()
            return true
        end
    },

    ["eject"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].set_stack("blueprint")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = -1},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_output)[1]
            if not (stack.valid_for_read and stack.name == "blueprint") then return false end
            
            stack.clear()
            
            return true
        end
    },
    ["ejectbook"] = {
        prepare = function()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[2].set_stack("blueprint-book")
        end,
        cc1 = {
            {signal = knownsignals.blueprint_book, count = -1},
        },
        verify = function()
            local stack = global.conman.get_inventory(defines.inventory.assembling_machine_output)[2]
            if not (stack.valid_for_read and stack.name == "blueprint-book") then return false end
            
            stack.clear()
            
            return true
        end
    },

    ["deploy"] = {
        prepare = function()
            --bp string of a single wooden chest
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 1},
            {signal = knownsignals.X, count = -3},
            {signal = knownsignals.Y, count = -3},
        },
        verify = function()
            local ghost = global.surface.find_entity('entity-ghost', {-2.5,-2.5})
            if not ghost then return false end
            ghost.destroy()
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].clear()
            return true
        end
    },
    ["captureentities"] = {
        prepare = function()
            -- build some entities and tiles
            global.entities={
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-3}},
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-5}},
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-5,-3}},
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-5,-5}},
            }

            local tiles = {}
            for x=-5,-3 do
                for y=-5,-3 do
                    tiles[#tiles+1] = {name="concrete",position={x,y}}
                end
            end
            global.surface.set_tiles(tiles)
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].set_stack("blueprint")            
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 2},
            {signal = knownsignals.X, count = -5},
            {signal = knownsignals.Y, count = -5},
            {signal = knownsignals.U, count = -3},
            {signal = knownsignals.V, count = -3},
            {signal = knownsignals.E, count = 1},
        },
        cc2string ="CAPTURE",
        verify = function()
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            local ents = bp.get_blueprint_entities()
            if ents and #ents ~= 4 then return false end
            local tiles = bp.get_blueprint_tiles()
            if tiles then return false end
            for _,ent in pairs(global.entities) do ent.destroy() end
            if bp.label ~= "CAPTURE" then return false end
            bp.clear()
            return true
        end
    },
    ["capturetiles"] = {
        prepare = function()
            -- build some entities and tiles
            global.entities={
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-3}},
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-5}},
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-5,-3}},
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-5,-5}},
            }

            local tiles = {}
            for x=-3,-5 do
                for y=-3,-5 do
                    tiles[#tiles+1] = {name="concrete",position={x,y}}
                end
            end
            global.surface.set_tiles(tiles)
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].set_stack("blueprint")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 2},
            {signal = knownsignals.X, count = -5},
            {signal = knownsignals.Y, count = -5},
            {signal = knownsignals.U, count = -3},
            {signal = knownsignals.V, count = -3},
            {signal = knownsignals.T, count = 1},
        },
        cc2string ="CAPTURE",
        cc2 = {
            {signal = knownsignals.red, count = 255},
            {signal = knownsignals.green, count = 255},
            {signal = knownsignals.blue, count = 255},
            {signal = knownsignals.white, count = 255},
        },
        verify = function()
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            local ents = bp.get_blueprint_entities()
            if ents then return false end
            local tiles = bp.get_blueprint_tiles()
            if tiles and #tiles ~= 9 then return false end
            for _,ent in pairs(global.entities) do ent.destroy() end
            if bp.label ~= "CAPTURE" then return false end
            local color = bp.label_color
            for _,v in pairs(color) do if v~=1 then return false end end
            bp.clear()
            return true
        end
    },
    ["bom"] = {
        prepare = function()
            --bp string of a single wooden chest
            global.conman.get_inventory(defines.inventory.assembling_machine_input)[1].import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 3},
        },
        verify = function(outsignals)
            if not outsignals or #outsignals ~= 1 or #outsignals[1] ~= 1 then return false end
            local sig = outsignals[1][1]
            return sig.count == 1 and sig.signal.name == "wooden-chest"
        end
    },

    ["readlabel"] = {
        prepare = function()
            --bp string of a single wooden chest
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
            bp.label = "TEST"
            bp.label_color = {r=12,g=34,b=56,a=78}

        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 4},
        },
        verify = function(outsignals)
            if not outsignals or #outsignals ~= 1 then return false end
            local signals = outsignals[1]
            local string = remote.call('signalstrings', 'signals_to_string', signals)
            if string ~= "TEST" then return false end
            return expect_signals({
                r = knownsignals.red,
                g = knownsignals.green,
                b = knownsignals.blue,
                a = knownsignals.white,
            }, {r=12,g=34,b=56,a=78} , signals, true)
            
        end
    },

    ["writelabel"] = {
        prepare = function()
            --bp string of a single wooden chest
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            global.bp = bp
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 4},
            {signal = knownsignals.W, count = 1},
        },
        cc2string = "TEST",
        cc2 = {
            {signal = knownsignals.red, count = 12},
            {signal = knownsignals.green, count = 34},
            {signal = knownsignals.blue, count = 56},
            {signal = knownsignals.white, count = 78},
        },
        verify = function(outsignals)
            if global.bp.label ~= "TEST" then return false end
            local color = global.bp.label_color
            global.bp = nil
            return --factorio returns colors as float values 0-1, but they're not exactly n/255 or n/256, so just make sure the difference is small...
                (color.r - 12/255 < 0.0001) and 
                (color.g - 34/255 < 0.0001) and 
                (color.b - 56/255 < 0.0001) and 
                (color.a - 78/255 < 0.0001)
        end
    },

    ["readicons"] = {
        prepare = function()
            --bp string of a single wooden chest
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 5},
        },
        verify = function(outsignals)
            if not outsignals or #outsignals ~= 1 or #outsignals[1] ~= 1 then return false end
            local signal = outsignals[1][1]
            return signal.count == 1 and signal.signal.name == "wooden-chest"
        end
    },
    ["writeicons"] = {
        prepare = function()
            --bp string of a single wooden chest
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            global.bp = bp
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 5},
            {signal = knownsignals.W, count = 1},
        },
        cc2 = {
            {signal = knownsignals.red, count = 1},
            {signal = knownsignals.green, count = 2},
            {signal = knownsignals.blue, count = 4},
            {signal = knownsignals.white, count = 8},
        },
        verify = function(outsignals)
            local icons = global.bp.blueprint_icons
            if not ( icons[1].index == 1 and icons[1].signal.name=="signal-red" ) then return false end
            if not ( icons[2].index == 2 and icons[2].signal.name=="signal-green" ) then return false end
            if not ( icons[3].index == 3 and icons[3].signal.name=="signal-blue" ) then return false end
            if not ( icons[4].index == 4 and icons[4].signal.name=="signal-white" ) then return false end
            return true
        end
    },

    ["readtile"] = {
        prepare = function()
            --bp string of a single wooden chest
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
            bp.set_blueprint_tiles({{name="concrete",position={1,1}}})
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 6},
            {signal = knownsignals.T, count = 1},
        },
        verify = function(outsignals)
            if not outsignals or #outsignals ~= 1 or #outsignals[1] ~= 3 then return false end
            return expect_signals({
                x = knownsignals.X,
                y = knownsignals.Y,
                concrete = {type="item",name="concrete"},
            }, {x=1, y=1, concrete=1}, outsignals[1])
        end
    },
    ["writetile"] = {
        prepare = function()
            --bp string of a single wooden chest
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            global.bp = bp
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        cc1 = {
            {signal = knownsignals.blueprint, count = 6},
            {signal = knownsignals.T, count = 1},
            {signal = knownsignals.W, count = 1},
            {signal = knownsignals.X, count = 1},
            {signal = knownsignals.Y, count = 1},
            {signal = {type="item",name="concrete"}, count = 1},
        },
        verify = function(outsignals)
            local tiles = global.bp.get_blueprint_tiles()
            if not tiles or #tiles ~= 1 then return false end
            local tile = tiles[1]
            if not ( tile.name == "concrete" and tile.position.x == 1 and tile.position.y == 1 ) then return false end
            return true
        end
    },


    
    ["readbooklabel"] = {
        prepare = function()
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            book.set_stack("blueprint-book")
            book.label = "TEST"
            book.label_color = {r=12,g=34,b=56,a=78}
            global.book = book
        end,
        cc1 = {
            {signal = knownsignals.blueprint_book, count = -4},
        },
        verify = function(outsignals)
            if not outsignals or #outsignals ~= 1 then return false end
            local signals = outsignals[1]
            local string = remote.call('signalstrings', 'signals_to_string', signals)
            if string ~= "TEST" then return false end
            global.book.clear()
            global.book = nil
            return expect_signals({
                r = knownsignals.red,
                g = knownsignals.green,
                b = knownsignals.blue,
                a = knownsignals.white,
            }, {r=12,g=34,b=56,a=78} , signals, true)
            
        end
    },

    ["writebooklabel"] = {
        prepare = function()
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            book.set_stack("blueprint-book")
            global.book = book
        end,
        cc1 = {
            {signal = knownsignals.blueprint_book, count = -4},
            {signal = knownsignals.W, count = 1},
        },
        cc2string = "TEST",
        cc2 = {
            {signal = knownsignals.red, count = 12},
            {signal = knownsignals.green, count = 34},
            {signal = knownsignals.blue, count = 56},
            {signal = knownsignals.white, count = 78},
        },
        verify = function(outsignals)
            if global.book.label ~= "TEST" then return false end
            local color = global.book.label_color
            global.book.clear()
            global.book = nil
            return --factorio returns colors as float values 0-1, but they're not exactly n/255 or n/256, so just make sure the difference is small...
                (color.r - 12/255 < 0.0001) and 
                (color.g - 34/255 < 0.0001) and 
                (color.b - 56/255 < 0.0001) and 
                (color.a - 78/255 < 0.0001)
        end
    },

    ["readbookcount"] = {
        prepare = function()
            local book = global.conman.get_inventory(defines.inventory.assembling_machine_input)[2]
            book.set_stack("blueprint-book")
            book.get_inventory(defines.inventory.item_main).insert{name="blueprint",count=3}
            global.book = book
        end,
        cc1 = {
            {signal = knownsignals.blueprint_book, count = -5},
        },
        verify = function(outsignals)
            if not outsignals or #outsignals ~= 1 then return false end
            local signals = outsignals[1]
            global.book.clear()
            global.book = nil
            return expect_signals({
                count = knownsignals.info,
            }, {count = 3} , signals)
            
        end
    },

    ["decon"] = {
        prepare = function()
            global.entities={
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-3}},
                global.surface.create_entity{name="tree-01",position={-3,-5}},
                global.surface.create_entity{name="rock-big",position={-5,-3}},
                global.surface.create_entity{name="cliff",position={-4,-4}},
            }
            global.wooden= global.surface.create_entity{name="wooden-chest",force=game.forces.player,position={-5,-5}}
        end,
        cc1 = {
            {signal = knownsignals.redprint, count = 1},
            {signal = knownsignals.X, count = -5},
            {signal = knownsignals.Y, count = -5},
            {signal = knownsignals.U, count = -3},
            {signal = knownsignals.V, count = -3},
        },
        verify = function()
            for _,ent in pairs(global.entities) do
                if not ent.to_be_deconstructed(game.forces.player) then return false end
                ent.destroy() 
            end
            if not global.wooden.to_be_deconstructed(game.forces.player) then return false end
            global.wooden.destroy()
            return true
        end
    },

    ["filterdecon"] = {
        prepare = function()
            global.entities={
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-3}},
                global.surface.create_entity{name="tree-01",position={-3,-5}},
                global.surface.create_entity{name="rock-big",position={-5,-3}},
                global.surface.create_entity{name="cliff",position={-4,-4}},
                
            }
            global.wooden= global.surface.create_entity{name="wooden-chest",force=game.forces.player,position={-5,-5}}
        end,
        cc1 = {
            {signal = knownsignals.redprint, count = 1},
            {signal = knownsignals.X, count = -5},
            {signal = knownsignals.Y, count = -5},
            {signal = knownsignals.U, count = -3},
            {signal = knownsignals.V, count = -3},
        },
        cc2 = {
            {signal = {type="item",name="steel-chest"}, count = 1},
            {signal = knownsignals.C, count = 1},
            {signal = knownsignals.T, count = 1},
            {signal = knownsignals.R, count = 1},
        },
        verify = function()
            for _,ent in pairs(global.entities) do
                if not ent.to_be_deconstructed(game.forces.player) then return false end
                ent.destroy() 
            end
            if global.wooden.to_be_deconstructed(game.forces.player) then return false end
            global.wooden.destroy()
            return true
        end
    },

    ["canceldecon"] = {
        prepare = function()
            global.entities={
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-3}},
                global.surface.create_entity{name="tree-01",position={-3,-5}},
                global.surface.create_entity{name="rock-big",position={-5,-3}},
                global.surface.create_entity{name="cliff",position={-4,-4}},
                
            }
            for _,ent in pairs(global.entities) do
                ent.order_deconstruction(game.forces.player) 
            end
            global.wooden= global.surface.create_entity{name="wooden-chest",force=game.forces.player,position={-5,-5}}
            global.wooden.order_deconstruction(game.forces.player)
        end,
        cc1 = {
            {signal = knownsignals.redprint, count = -1},
            {signal = knownsignals.X, count = -5},
            {signal = knownsignals.Y, count = -5},
            {signal = knownsignals.U, count = -3},
            {signal = knownsignals.V, count = -3},
        },
        verify = function()
            for _,ent in pairs(global.entities) do
                if ent.to_be_deconstructed(game.forces.player) then return false end
                ent.destroy() 
            end
            if global.wooden.to_be_deconstructed(game.forces.player) then return false end
            global.wooden.destroy()
            return true
        end
    },
    ["filtercanceldecon"] = {
        prepare = function()
            global.entities={
                global.surface.create_entity{name="steel-chest",force=game.forces.player,position={-3,-3}},
                global.surface.create_entity{name="tree-01",position={-3,-5}},
                global.surface.create_entity{name="rock-big",position={-5,-3}},
                global.surface.create_entity{name="cliff",position={-4,-4}},
                
            }
            for _,ent in pairs(global.entities) do
                ent.order_deconstruction(game.forces.player) 
            end
            global.wooden= global.surface.create_entity{name="wooden-chest",force=game.forces.player,position={-5,-5}}
            global.wooden.order_deconstruction(game.forces.player)
        end,
        cc1 = {
            {signal = knownsignals.redprint, count = -1},
            {signal = knownsignals.X, count = -5},
            {signal = knownsignals.Y, count = -5},
            {signal = knownsignals.U, count = -3},
            {signal = knownsignals.V, count = -3},
        },
        cc2 = {
            {signal = {type="item",name="steel-chest"}, count = 1},
            {signal = knownsignals.C, count = 1},
            {signal = knownsignals.T, count = 1},
            {signal = knownsignals.R, count = 1},
        },
        verify = function()
            for _,ent in pairs(global.entities) do
                if ent.to_be_deconstructed(game.forces.player) then return false end
                ent.destroy() 
            end
            if not global.wooden.to_be_deconstructed(game.forces.player) then return false end
            global.wooden.destroy()
            return true
        end
    },
    ["dump"] = {
        prepare = function()
            local bp = global.conman.get_inventory(defines.inventory.assembling_machine_input)[1]
            global.bp = bp
            bp.import_stack("0eNptjt0KwjAMhd/lXFfYmOLsq4jIfoIGtnSs2XSMvrttvfHCm8AJX76THe2w0DSzKOwO7px42OsOzw9phrTTbSJYsNIIA2nGlF7O9SSH7kleEQxYenrDluFmQKKsTF9PDttdlrGlOQL/DQaT8/HISWqMosJgizMkX262P48arDT7DJ+roqzr6ng5RfYDM+FESw==")
        end,
        multifeed = {
            {
                cc1 = {
                    {signal = knownsignals.blueprint, count = 11},
                },
            },
            {},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},
        },
        verify = function(outsignals)
            log(serpent.dump(outsignals))
            
            return false
        end
    },
    
    ["profileend"] ={
        prepare = function()
            
        end,
        cc1 = {

        },
        cc2 = {

        },
        verify = function()
            if remote.call("conman","hasProfiler") then
                global.profilecount = (global.profilecount or 0) + 1
                if global.profilecount == 50 then
                    remote.call("conman","stopProfile")
                else
                    global.testid = nil
                end
            end
            return true
        end
    },
    
    -- ]]
}

local states = {
    prepare = 10,       -- run prepare()
    feed = 20,          -- feed cc1/cc2
    multifeed = 21,     -- feed for multi-frame commands
    clear = 30,         -- clear commands, extra tick for them to execute
    verify = 40,        -- run verify() to test result
    finished = -1,      -- testing stopped
}


script.on_event(defines.events.on_game_created_from_scenario,function()
    game.print("init")
    if Coverage then Coverage.Start("conman_tests") end
    game.autosave_enabled = false
    game.speed = 1000
    global = {
        surface = game.surfaces['nauvis']
    }

    -- make sure things like high stacks on inserters are unlocked so setting them works
    game.forces.player.research_all_technologies()
    
    global.testid,global.test = next(tests)
    global.state = states.prepare
    
    local tags = { "testprobe1", "testprobe2", "testprobe2out", "conman" }
    for _,tag in pairs(tags) do 
        global[tag] = game.get_entity_by_tag(tag)
    end

end)

local function writeInput(signals,string,entity)
    local outframe = {}
    if string then 
        signals = remote.call('signalstrings', 'string_to_signals', string, signals)
    end

    if signals then
        for i,signal in pairs(signals) do
            outframe[#outframe+1] = {index=#outframe+1, count=signal.count, signal=signal.signal}
        end
    end
    entity.get_or_create_control_behavior().parameters={parameters = outframe}
end

script.on_event(defines.events.on_tick, function()
    if global.state == states.prepare then
        game.print("prepare " .. global.testid)
        if Coverage then Coverage.Start(global.testid) end
        global.outsignals = {}
        if global.test.prepare then
            global.test.prepare()
        end
        if global.test.multifeed then 
            global.nextfeed = 1
            global.state = states.multifeed
        else
            global.state = states.feed
        end
    elseif global.state == states.feed then
        game.print("feed " .. global.testid)
        -- feed cc1/cc2 data
        writeInput(global.test.cc1, global.test.cc1string, global.testprobe1)
        writeInput(global.test.cc2, global.test.cc2string, global.testprobe2)
        global.outsignals[1] = global.testprobe2out.get_merged_signals()
        global.state = states.clear
    elseif global.state == states.multifeed then
        game.print("multifeed " .. global.testid .. " " .. global.nextfeed)
        -- feed cc1/cc2 data
        local nextdata = global.test.multifeed[global.nextfeed]
        writeInput(nextdata.cc1, nextdata.cc1string, global.testprobe1)
        writeInput(nextdata.cc2, nextdata.cc2string, global.testprobe2)
        
        global.outsignals[global.nextfeed] = global.testprobe2out.get_merged_signals()
        
        if global.test.multifeed[global.nextfeed+1] then
            global.nextfeed = global.nextfeed + 1
        else
            global.state = states.clear
        end
    elseif global.state == states.clear then
        game.print("clear " .. global.testid)
        -- clear cc1/cc2 data
        writeInput(nil,nil, global.testprobe1)
        writeInput(nil,nil, global.testprobe2)

        -- read cc2 output
        global.outsignals[#global.outsignals+1] = global.testprobe2out.get_merged_signals()
        global.state = states.verify
    elseif global.state == states.verify then
        game.print("verify " .. global.testid)
    
        if global.test.verify then
            global.outsignals[#global.outsignals+1] = global.testprobe2out.get_merged_signals()
            if not global.test.verify(global.outsignals) then
                --game.set_game_state{ game_finished=true, player_won=false, can_continue=true }    
                global.state = states.finished
                game.speed = 1
                game.print("test failed")
                remote.call("conman","stopProfile")
                if Coverage then
                    Coverage.Stop()
                    Coverage.Report()
                end
                return
            end
        end
        
        -- set up for next test
        global.testid,global.test = next(tests,global.testid)
        if global.testid then
            global.state = states.prepare
        else
            global.state = states.finished
            game.speed = 1
            if Coverage then
                Coverage.Stop()
                Coverage.Report()
            end
            --game.set_game_state{ game_finished=true, player_won=true, can_continue=false }
        end
    end
end)