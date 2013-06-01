Ext.define "Muleview.Settings",

  muleUrlPrefix: "" # Base URL to Mule
  updateInterval: 1000 * 60 * 5 # Graph auto-refresh rate (millis)
  labelTimeFormat: "H:i" # Graph label time format, see http://docs.sencha.com/ext-js/4-2/#!/api/Ext.Date for formatting options
  labelDateFormat: "d/m/y" # Graph label date format, see above
  tipFormat: "d/m/y" # Graph Tooltip  date format, see above
  statusTimeFormat: "l, NS \\o\\f F Y, G:i:s" # Status-bar's time format, see above.
  othersSubkeyName: "(Others)" # Key name used to store sum of hidden subkeys
  defaultSubkeys: 15 # How much subkeys to initially display (the rest will be summed in "(Others)")
  subkeysOffsetAllowed: 3 # Start packing smaller subkeys after these amount has passed the defaultSubkeys amount

  subkeyHeuristics: # These settings determine how default subkeys are selected
    sampleCount: 5 # Amount of samples to take when calculating subkey heuristics
    base: 3 # Exponentiation base
    coefficientMin: 0.8 # How much to multiply the the weight of the oldest value
    coefficientMax: 1.2 # How much to multiply the weight of the newest value

  # The following settings should probably not be changed:
  alerts: [
   # NOTE: the order determines how mule responses are parsed!
      name: "critical_low"
      label: "Critical Low"
      color: "black"
    ,
      name: "warning_low"
      label: "Warning Low"
    ,
      name: "warning_high"
      label: "Warning High"
      color: "purple"
    ,
      name: "critical_high"
      label: "Critical High"
      color: "yellow"
    ,
      name: "period"
      label: "Period"
      time: true
    ,
      name: "stale"
      label: "Stale"
      time: true
  ]
  singleton: true
