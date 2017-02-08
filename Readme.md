### Conman
main entity is assembly machine with special `blueprint -> blueprint` recipe
  * sub entities:
    * CC Control 1: primary commands - SW corner
    * CC Control 2: secondary data - SE corner
    * Control nodes only read one wire - if both are connected it will use the red one. Use a combinator to merge wires if required. This is mostly a performance optimization.

### Commands:
* conbot + item signal + D=dir + X,Y=pos : build entity
  * optional: R=recipeid (with recipeid lib)
  * optional: filters or CC data on Control2
  * optional: other entity specific?
* r/g/c wire + XY(z) + UV(w) [not yet implemented]
  * connent entites at XY and UV with wire, ports z/w if multiple
  * UV unspecified will used last-built entity
* blueprint=-1 : eject blueprint
  * transfer from input to output inventory
* blueprint=1 + XY : deploy print at XY
  * optional: F=force - auto decon trees/rocks in the way
* blueprint=2 + XYWH : Capture print from XYWH
  * optional: TEM=what to capture, tiles/entities/modules
  * optional: Control2: signalstring of new blueprint name (with singalstrings lib)
* blueprint=3: read print info [not yet implemented]
  * output to Control2: Blueprint label string and color
  * output to Control2: Blueprint BoM or icons?
* redprint=1 + XYWH rectangle : decon order
  * optional: filters on Control2
    * T = trees
    * R = rocks
    * if empty, decon all!!!
* redprint=-1 + XYWH rectangle : cancel decon order
  * optional: filters on Control2
    * T = trees
    * R = rocks
    * if empty, decon all!!!
