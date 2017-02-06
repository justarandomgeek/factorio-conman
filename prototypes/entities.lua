
local conmanent = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
conmanent.name="conman"
conmanent.minable.result = "conman"
conmanent.fast_replaceable_group = nil
conmanent.crafting_categories = {"conman"}
conmanent.crafting_speed = 1
conmanent.ingredient_count = 4
conmanent.module_specification = nil
conmanent.allowed_effects = nil
print(serpent.block(conmanent))
data:extend{conmanent}
print(data.raw["assembling-machine"]["conman"].name .. 'added')


local conmanctrl = table.deepcopy(data.raw["constant-combinator"]["constant-combinator"])
conmanctrl.name="conman-control"
conmanctrl.minable.result = "conman-control"
conmanctrl.order="z[lol]-[conmanctrl]"
data:extend{conmanctrl}
