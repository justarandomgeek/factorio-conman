### ConMan - Construction Manager

ConMan allows you to order construction and deconstruction via the circuit network. Limited construction of individual entities can be done directly, and any blueprints can be usedmo

  * sub entities:
    * CC Control 1: primary commands - SW corner
    * CC Control 2: secondary data - SE corner
    * Control nodes only read one wire - if both are connected it will only read the red one. Use a combinator to merge wires if required. This is mostly a performance optimization, and is not likely to change.

### Commands:
* conbot + item signal + D=dir + X,Y=pos : Construction Order
  * optional: B=bar : Number of slots usable in a chest
  * optional: R=recipeid (with recipeid lib)
  * optional: filters or CC data on Control2
  * optional: other entity specific?
* r/g/c wire + XY(z) + UV(w) [not yet implemented]
  * connect entities at XY and UV with wire, ports z/w if multiple
* blueprint=-1 : Eject Blueprint
  * transfer from input to output inventory
* blueprint=1 + XY : Deploy Blueprint
  * optional: F=force - auto decon trees/rocks in the way
* blueprint=2 + XYWH : Capture Blueprint
  * optional: TEM=what to capture, tiles/entities/modules
  * optional: Control2: signalstring of new blueprint name (with singalstrings lib)
* blueprint=3: Read Blueprint Info
  * output to Control2: Blueprint label string and color if set
  * output to Control2: Blueprint BoM
* redprint=1 + XYWH : Deconstruction Order
  * redprint=-1 to cancel
  * optional: filters on Control2
    * T = trees
    * R = rocks
    * if empty, decon all!!!
