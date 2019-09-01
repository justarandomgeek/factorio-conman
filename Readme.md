# ConMan

ConMan allows you to manage construction and deconstruction orders via the circuit network. Construction/deconstruction of individual entities can be ordered, as well as capturing and deploying entire blueprints. Additionally, Item Requests can be ordered on any entity, and artillery strikes can be ordered.

Because of the complexity of the command set, ConMan requires two connectors, Control 1 and Control 2, placed in the lower corners. Control 1 is input-only, and is the primary command input. Control 2 is either an additional input or output data depending on the command.

`image of ConMan with Controls marked`


[Command Set Reference](https://docs.google.com/spreadsheets/d/1EwpnEpIH5FDuhOyAfHpYr0tIxa_Wt9LgixO274a2zlM/edit?usp=sharing)

### Positions

ConMan uses absolute positions for nearly all operations, so it is reccomended to use the Location Combinator from [Utility Combinators](https://mods.factorio.com/mod/utility-combinators) for a location reference. ConMan does not currently support any operations across surfaces. When an operation requires one position arguement, it is supplied on ![X] and ![Y]. When an operation requires two position arguments or a bounding box, the first point is supplied on ![X] and ![Y] and the second on ![U] and ![V].