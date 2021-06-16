return {
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
    L = {name="signal-L",type="virtual"}, -- roboport report lognet
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
  
    grey = {name="signal-grey",type="virtual"},
    white = {name="signal-white",type="virtual"},
    red = {name="signal-red",type="virtual"},
    green = {name="signal-green",type="virtual"},
    blue = {name="signal-blue",type="virtual"},

    info = {name="signal-info",type="virtual"},
  
    blueprint = {name="blueprint",type="item"},
    blueprint_book = {name= "blueprint-book", type= "item"},
    redprint = {name="deconstruction-planner",type="item"},
    upgrade = {name="upgrade-planner",type="item"},
    conbot = {name="construction-robot",type="item"},
    logbot = {name="logistic-robot",type="item"},
  
    redwire = {name="red-wire",type="item"},
    greenwire = {name="green-wire",type="item"},
    coppercable = {name="copper-cable",type="item"},
  
    -- stringy train stops defines this
    schedule = {name="signal-schedule",type="virtual"},
  }
