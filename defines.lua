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
}