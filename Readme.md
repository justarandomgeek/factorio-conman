# ConMan

ConMan allows you to manage construction and deconstruction orders via the circuit network. Construction/deconstruction of individual entities can be ordered, as well as capturing and deploying entire blueprints. Additionally, Item Requests can be ordered on any entity, and artillery strikes can be ordered.

Because of the complexity of the command set, ConMan requires two connectors, Control 1 and Control 2, placed in the lower corners. Control 1 is input-only, and is the primary command input. Control 2 is either an additional input or output data depending on the command.

`image of ConMan with Controls marked`


### Positions

ConMan uses absolute positions for nearly all operations, so it is reccomended to use the Location Combinator from [Utility Combinators](https://mods.factorio.com/mod/utility-combinators) for a location reference. ConMan does not currently support any operations across surfaces. When an operation requires one position arguement, it is supplied on ![X] and ![Y]. When an operation requires two position arguments or a bounding box, the first point is supplied on ![X] and ![Y] and the second on ![U] and ![V].


### Circuit Configurations


Conditions: circuit:C=1, logistics:L=1, op:O=opindex, signalmode:S firstconstant:J secondconstant:K output1:F

| ![O]  | Arithmetic Op | Decider Op |
|----|---------------|------------|
| 1  | *             | <          |
| 2  | /             | >          |
| 3  | +             | =          |
| 4  | -             | ≥          |
| 5  | %             | ≤          |
| 6  | ^             | ≠          |
| 7  | <<            | n/a        |
| 8  | >>            | n/a        |
| 9  | AND           | n/a        |
| 10 | OR            | n/a        |
| 11 | XOR           | n/a        |


| ![S] | Special Signal Mode           |
|---|-----------------------|
| 0 | Scalars               |
| 1 | Each in               |
| 2 | Each in & out         |
| 3 | Any in                |
| 4 | Any in & Every out    |
| 5 | Every in              |
| 6 | Every in & Every out  |
| 7 | Scalar in & Every out |

Signal lists for decider/arithmetic combinators are provided on Control 2 (input) by setting sequential bits in the selected signals.

| bit  | Signal slot   |
|------|---------------|
| 0x01 | First Signal  |
| 0x02 | Second Signal |
| 0x04 | Output Signal |




## Commands

### Order Construction

 * ![conbot]=1
 * ![D] = Direction. 8 steps starting from North
 * ![X]![Y] = Position.

One of:

| Item Build Result     | Control 1 Extra Data           | Control 2 Data                                                        |
|-----------------------|--------------------------------|-----------------------------------------------------------------------|
| assembling-machine    | ![R]ecipe                      | IN: one-time item requests                                            |
| chest                 | Inventory ![B]ar               | IN: one-time item requests                                            |
| logistics-container   | Inventory ![B]ar               | IN: logistics requests                                                |
| cargo-wagon           | Inventory ![B]ar               | IN: inventory filters (bitmask, high bit repeated until end of wagon) |
| constant-combinator   |                                | IN: data                                                              |
| arithmetic-combinator | ![O]peration ![S]pecial signal | IN: signal list (bitmasks)                                            |
| decider-combinator    | ![O]peration ![S]pecial signal | IN: signal list (bitmasks)                                            |
| tiles                 |                                |                                                                       |
| other entities        |                                | IN: one-time item requests                                            |

A ghost for the selected/configured entity will be placed at ![X]![Y].


### Order Item Delivery

 * ![logbot]=1
 * ![X]![Y] = Position.

Control 2 (input) = Items to delivery


An `item-request-proxy` will be created on the entity at ![X]![Y] for the items specified on Control 2.


### Connect Wire

 * ![redwire] or ![greenwire] or ![copperwire] =1
 * ![X]![Y] = Position 1
 * ![Z] = Connector ID 1
 * ![U]![V] = Position 2
 * ![W] = Connector ID 2


The selected wire will be connected. ![Z] and ![W] are only required if the entity selected by the corresponding position is a combinator with multiple connectors.

### Disconnect Wire

 * ![redwire] or ![greenwire] or ![copperwire] = -1
 * ![X]![Y] = Position 1
 * ![Z] = Connector ID 1
 * ![U]![V] = Position 2
 * ![W] = Connector ID 2


The selected wire will be disconnected. ![Z] and ![W] are only required if the entity selected by the corresponding position is a combinator with multiple connectors.

### Eject Blueprint

 * ![blueprint] = -1


The blueprint in the input/working inventory (if present) will be moved to the output inventory.

### Deploy Blueprint

 * ![blueprint] = 1
 * ![X]![Y] = Blueprint origin
 * ![F] = Force build


The blueprint in the input/working inventory (if present) will be deployed at the specified postion. If ![F] is non-zero, proceed even if part of teh blueprint is unbuildable (and remove trees/rocks if required).

### Capture Blueprint

 * ![blueprint] = 2
 * ![X]![Y]![U]![V] = Blueprint area
 * ![T]![E]![M] = flags to capture tiles/entities/modules

Control 2 (input) = SignalString of blueprint name + ![red]![green]![blue]![white] 0-255 name color


The blueprint in the input/working inventory (if present) will be used to capture teh specified area, and saved with the provided name.

### Read Blueprint Info

 * ![blueprint] = 3

Control 2 (output) = items to build blueprint + SignalString name + ![red]![green]![blue]![white] 0-255 name color


The items needed to build the blueprint in the input/working inventory (if present), along with its name, will be output to Control 2


### Order Deconstruction



  * redprint=1 + BoundingBox : Deconstruction Order
    * redprint=-1 to cancel
    * optional: filters on Control2
      * T = trees
      * R = rocks
      * if empty, decon all!!!
  * artillery remote + XY: Artillery Targetting order. Modded artillery remotes also work.
  * signal-schedule: If Stringy Train Stops is installed, ConMan can use the same commands to build a schedule, and program it into any train. When sending -1 to program/start the schedule, also send XY to select a train to be programmed. Note that you must *NOT* send XY (or other position signals) while building the schedule, as those signals are used to form the stop name. Also note that trains cannot be programmed with a schedule until after they are constructed.



## Test Rig

![Annotatted Test Rig](conman_annotated.png)
This is a test rig for manually inputting commands. I use this for developing/testing commands. This requires my mods Location Combinator, Pushbutton, and Nixie Tubes.

The [blueprint](ConMan Test Rig.blueprint) will configure it ready for use.

The cursor box shows the XY and UV selections in red and green, respectively. For rectangle selections, XY shoudl be the upper/left, and UV should be lower/right. The cursors are moved by the two D-pads, and can be reset to the upper left using the black button in the center. Cursor selections outside the box are valid, but will not be drawn due to physical limitations of the display.

When placing direction entities, their facing can be selected using the compass below the D-pads. There are buttons to rotate each direction one or two steps, and to reset to North.

When placing chests, the bar (red X to block inserters) can be set using the 'B' selector to the left of the D-Pad.

Onces a position and direction are selected, a construction order can be placed by selecting one of the item buttons (add/reconfigure as required).

Wires can be connected/disconnected(X) by selecting two positions, and pressing the corresponding wire button. the Z/W toggles next to the D-Pads will select the second port of combinators for red/green wire.

For commands which take signals from CC2, there are constant combinators configured for easy toggling (especially with Pushbutton mod - press 'f' to toggle constant combinators!). These can be used to set filters for deconstruction orders, or for entity-specific configuration sa required by construction orders. The name for a captured blueprint can also be provided here, if Signal Strings is also installed. These toggles are also used to set the items for Delivery orders, which can be placed using the LogBot button.

Blueprints may be used to copy large areas directly, but one must be inserted into ConMan first. Blueprints may be:
  * Deployed, using the button with only a blueprint on it. The print will deploy centered on the XY cursor.
  * Force-deployed, using Blueprint+F. The print will be deployed as if shift-clicked.
  * Ejected, using Blueprint+Fast Inserter button. The print will be ejected to the chest beside ConMan. The button directly beside ConMan will reload it.
  * Captured, using Blueprint+C. The print will capture the area selected by the two cursors. If Signal Strings is present, it will also read a name from CC2 for the print.
  * Described, using Blueprint+I. The print name (with Signal Strings) and item needs will be output to the memory cell below CC2.

Deconstruction orders can be placed and cancelled using the Redprint and Redprint+X buttons, and a rectangle selection. If any signals are read on CC2, this will only affect things selected by these signals as filters.
