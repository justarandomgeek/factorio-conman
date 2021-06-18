return {
  ---@param signal SignalID
  ---@param set Signal[]
  ---@return number
  get_signal_from_set = function(signal,set)
    for _,sig in pairs(set) do
      if sig.signal.type == signal.type and sig.signal.name == signal.name then
        return sig.count
      end
    end
    return 0
  end,

  ---@generic T
  ---@param filters table<T,SignalID>
  ---@param signals Signal[]
  ---@return table<T,number>
  get_signals_filtered = function(filters,signals)
    local results = {}
    local count = 0
    for _,sig in pairs(signals) do
      for i,f in pairs(filters) do
        if f.name and sig.signal.type == f.type and sig.signal.name == f.name then
          results[i] = sig.count
          count = count + 1
          if count == #filters then return results end
        end
      end
    end
    return results
  end,

}