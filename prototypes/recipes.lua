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
      {"blueprint", 1},
      {"deconstruction-planner", 1},
      {"upgrade-planner", 1},
      {"blueprint-book", 1},
    },
    results =
    {
      {type="item", name="blueprint",amount=1 },
      {type="item", name="deconstruction-planner", amount=1 },
      {type="item", name="upgrade-planner", amount=1 },
      {type="item", name="blueprint-book", amount=1 },
    },
    main_product= "blueprint",
    icon = "__base__/graphics/icons/roboport.png",
    icon_size = 32,
  },

}
