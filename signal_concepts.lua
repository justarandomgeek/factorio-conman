local knownsignals = require("knownsignals")
local signal_util = require("signal_util")
local get_signal_from_set = signal_util.get_signal_from_set
local get_signals_filtered = signal_util.get_signals_filtered


local signalsets = {
  position1 = {
    x = knownsignals.X,
    y = knownsignals.Y,
  },
  position2 = {
    x = knownsignals.U,
    y = knownsignals.V,
  },
  color = {
    r = knownsignals.red,
    g = knownsignals.green,
    b = knownsignals.blue,
  }
}

---@param manager? ConManManager
---@param signals Signal[]
---@param secondary? boolean
---@param offset? Position
---@return Position
local function ReadPosition(manager,signals,secondary,offset,raw)
  local set = secondary and signalsets.position2 or signalsets.position1
  local p = get_signals_filtered(set,signals)
  local x,y = (p.x or 0),(p.y or 0)
  if offset then
    x = x+offset.x
    y = y+offset.y
  end
  if manager then
    if manager.relative then
      local mpos = manager.ent.position
      x = x + mpos.x
      y = y + mpos.y
    end
    local moff = manager.offset
    if moff then
      x = x + moff.x
      y = y + moff.y
    end
  end
  p.x = x
  p.y = y
  return p
end

---@param signals Signal[]
---@return Color
local function ReadColor(signals)
  local color = get_signals_filtered(signalsets.color,signals)
  color.r =  math.min(math.max(color.r, 0), 255)
  color.g =  math.min(math.max(color.g, 0), 255)
  color.b =  math.min(math.max(color.b, 0), 255)
  return color
end

---@param manager? ConManManager
---@param signals Signal[]
---@return BoundingBox
local function ReadBoundingBox(manager,signals)
  -- adjust offests to make *inclusive* selection
  return {ReadPosition(manager,signals,false,{x=0,y=0}),ReadPosition(manager,signals,true,{x=1,y=1})}
end


---@param signals Signal[]
---@param count? number
---@return LogisticFilter[]
local function ReadFilters(signals,count)
  local filters = {}
  if signals then
    for i,s in pairs(signals) do
      if s.signal.type == "item" then
        filters[#filters+1]={index = #filters+1, name = s.signal.name, count = s.count}
        if count and #filters==count then break end
      end
    end
  end
  return filters
end

---@param signals Signal[]
---@param count? number
---@return InventoryFilter[]
local function ReadInventoryFilters(signals,count)
  local filters = {}
  local nfilters = 0
  if signals then
    for _,s in pairs(signals) do
      if s.signal.type == "item" then
        for b=0,31 do
          local bit = bit32.extract(s.count,b)
          if bit == 1 and not filters[b+1] then
            filters[b+1]={index = b+1, name = s.signal.name}
            nfilters = nfilters +1
            if b == 31 and count > 31 then
              for n=32,count do
                filters[n]={index = n, name = s.signal.name}
                nfilters = nfilters +1
              end
            end
          end
        end
      end
    end
  end
  return filters
end

---@param signals Signal[]
---@param count? number
---@return table<string,number>
local function ReadItems(signals,count)
  local items = {}
  if signals then
    for i,s in pairs(signals) do
      if s.signal.type == "item" then
        local n = s.count
        if n < 0 then n = n + 0x100000000 end
        items[s.signal.name] = n
        if count and #items==count then break end
      end
    end
  end
  return items
end

--TODO use iconstrip reader from magiclamp?

---@param signals Signal[]
---@param nbits? number
---@return SignalID[]
local function ReadSignalList(signals,nbits)
  local selected = {}
  for i=0,(nbits or 31) do
    for _,sig in pairs(signals) do
      local sigbit = bit32.extract(sig.count,i)
      if sigbit==1 then
        selected[i+1] = sig.signal
        break
      end
    end
  end
  return selected
end

return {
  ReadPosition = ReadPosition,
  ReadColor = ReadColor,
  ReadBoundingBox = ReadBoundingBox,
  ReadFilters = ReadFilters,
  ReadInventoryFilters = ReadInventoryFilters,
  ReadItems = ReadItems,
  ReadSignalList = ReadSignalList,
}