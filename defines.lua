return {
  inv_index = {
    bp = 1,
    upgrade = 2,
    decon = 3,
    book = 4,
  },
  arithop = { "*", "/", "+", "-", "%", "^", "<<", ">>", "AND", "OR", "XOR" },
  deciderop = { "<", ">", "=", "≥", "≤", "≠" },
  specials = {
    each  = {name="signal-each",       type="virtual"},
    any   = {name="signal-anything",   type="virtual"},
    every = {name="signal-everything", type="virtual"},
  },
  EntityTypeToControlBehavior = 
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
  },
}