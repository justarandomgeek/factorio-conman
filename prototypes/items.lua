data:extend{
  {
    type = "item",
    name = "conman",
    icon = "__base__/graphics/icons/roboport.png",
    icon_size = 64,
    subgroup = "logistic-network",
    order = "c[signal]-b[conman]",
    place_result="conman",
    stack_size = 50,
  },
  {
    type = "item",
    name = "conman-control",
    icon = "__base__/graphics/icons/roboport.png",
    icon_size = 64,
    flags = {"hidden"},
    subgroup = "logistic-network",
    order = "c[signal]-b[conman-control]",
    place_result="conman-control",
    stack_size = 50,
  },
  }
