data:extend{
  {
    type = "recipe",
    name = "conman",
    enabled = "true",
    ingredients =
    {
      {"assembling-machine-2", 1},
      {"constant-combinator", 2},
      {"roboport", 1},
    },
    result="conman",
  },

  {
    type = "recipe-category",
    name = "conman"
  },
  {
    type = "recipe",
    name = "conman-process",
    enabled = false,
    energy_required = 1,
    category = "conman",
    ingredients =
    {
      {"blueprint", 1}
    },
    result = "blueprint",
    result_count = 1,
    icon = "__base__/graphics/icons/roboport.png",
    icon_size = 32,
  },

}
