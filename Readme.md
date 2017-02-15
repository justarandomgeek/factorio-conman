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
* logbot + items on Control2 + XY : Delivery order
  * Deliver items specified by Control2 to entity at XY
  * Note that these items will be delivered by conbots despite being signalled by logbot.
* r/g/c wire + XY(Z) + UV(W)
  * connect entities at positions XY and UV with wire, ports Z/W if multiple
  * negative wire to disconnect
* blueprint=-1 : Eject Blueprint
  * transfer from input to output inventory
* blueprint=1 + XY : Deploy Blueprint
  * optional: F=force - auto decon trees/rocks in the way
* blueprint=2 + XYUV=boundingbox : Capture Blueprint
  * optional: TEM=what to capture, tiles/entities/modules
  * optional: Control2: signalstring of new blueprint name (with singalstrings lib)
* blueprint=3: Read Blueprint Info
  * output to Control2: Blueprint label string and color if set
  * output to Control2: Blueprint BoM
* redprint=1 + XYUV : Deconstruction Order
  * redprint=-1 to cancel
  * optional: filters on Control2
    * T = trees
    * R = rocks
    * if empty, decon all!!!
