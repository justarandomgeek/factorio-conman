local knownsignals = {
A = {name="signal-A",type="virtual"}, -- show alerts
B = {name="signal-B",type="virtual"}, -- bar
C = {name="signal-C",type="virtual"}, -- use colors
D = {name="signal-D",type="virtual"}, -- direction
E = {name="signal-E",type="virtual"}, -- enable/disable mode, open gate
F = {name="signal-F",type="virtual"}, -- force build blueprint
                                        -- combinator "flag" (=1) output
                                        -- inserters set filters from signals
G = {name="signal-G",type="virtual"}, -- global playback
I = {name="signal-I",type="virtual"}, -- splitter input priority
                                        -- inserter overrice stack size
                                        -- speaker instrument
J = {name="signal-J",type="virtual"}, -- combinator first constant
                                        -- speaker pitch
K = {name="signal-K",type="virtual"}, -- second constant
M = {name="signal-M",type="virtual"}, -- show on map
O = {name="signal-O",type="virtual"}, -- combinator operation
P = {name="signal-P",type="virtual"}, -- allow polyphony
R = {name="signal-R",type="virtual"}, -- recipeid (with recipeid mod)
                                        -- read mode (various machines)
                                        -- infinity chest remove unfiltered
S = {name="signal-S",type="virtual"}, -- combinator special signal mode
T = {name="signal-T",type="virtual"}, -- captured blueprint incldues tiles
                                        -- train stop send signals to train

U = {name="signal-U",type="virtual"}, -- X2
                                        -- loader "unload"
                                        -- underground belt "up"
V = {name="signal-V",type="virtual"}, -- Y2
                                        -- speaker signal value is pitch
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

local tests = {
    ["testname"] ={
        prepare = function()

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
                control.circuit_mode_of_operation == defines.control_behavior.logistic_container.circuit_mode_of_operation.set_requests	
                --TODO: verify request_from_buffer
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
            {signal = knownsignals.B, count = 2},
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
                control.parameters.parameters.second_signal.name == "signal-B" and
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
            {signal = knownsignals.B, count = 2},
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
                control.parameters.parameters.second_signal.name == "signal-B" and
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
    -- ]]
}


-- for each test 1tick each:
--   run prepare()
--   feed CC1/CC2 data
--   clear input probes, capture CC2 output
--   run verify(CC2out)

local states = {
    prepare = 1,
    feed = 2,
    clear = 3,
    verify = 4,
    finished = -1,
}


script.on_init(function()
    game.print("init")
    global = {
        surface = game.surfaces['nauvis']
    }

    global.testid,global.test = next(tests)
    global.state = states.prepare
    
    local tags = { "testprobe1", "testprobe2", "testprobe2out", "conman" }
    for _,tag in pairs(tags) do 
        global[tag] = game.get_entity_by_tag(tag)
    end

end)

script.on_event(defines.events.on_tick, function()
    if global.state == states.prepare then
        game.print("prepare " .. global.testid)
        if global.test.prepare then
            global.test.prepare()
        end
        global.state = states.feed
    elseif global.state == states.feed then
        game.print("feed " .. global.testid)
        -- feed cc1/cc2 data
        local outframe1 = {}
        for i,signal in pairs(global.test.cc1) do
            outframe1[#outframe1+1] = {index=#outframe1+1, count=signal.count, signal=signal.signal}
        end
        global.testprobe1.get_or_create_control_behavior().parameters={parameters = outframe1}

        local outframe2 = {}
        for i,signal in pairs(global.test.cc2) do
            outframe2[#outframe2+1] = {index=#outframe2+1, count=signal.count, signal=signal.signal}
        end
        global.testprobe2.get_or_create_control_behavior().parameters={parameters = outframe2}

        global.state = states.clear
    elseif global.state == states.clear then
        game.print("clear " .. global.testid)
        -- clear cc1/cc2 data
        global.testprobe1.get_or_create_control_behavior().parameters=nil
        global.testprobe2.get_or_create_control_behavior().parameters=nil

        -- read cc2 output
        global.outsignals = global.testprobe2out.get_merged_signals()
        global.state = states.verify
    elseif global.state == states.verify then
        game.print("verify " .. global.testid)
    
        if global.test.verify then
            if not global.test.verify(outsignals) then
                --game.set_game_state{ game_finished=true, player_won=false, can_continue=true }    
                global.state = states.finished
                game.print("test failed")
                return
            end
        end
        
        -- set up for next test
        global.testid,global.test = next(tests,global.testid)
        if global.testid then
            global.state = states.prepare
        else
            global.state = states.finished
            --game.set_game_state{ game_finished=true, player_won=true, can_continue=false }
        end
    end
end)