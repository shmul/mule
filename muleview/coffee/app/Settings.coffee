Ext.define "Muleview.Settings",

  muleUrlPrefix: "" # Base URL to Mule
  updateInterval: 1000 * 60 * 5 # Graph auto-refresh rate (millis)
  labelFormat: "d/m/y H:i:s" # Graph label format, see http://docs.sencha.com/ext-js/4-1/#!/api/Ext.Date for formatting options
  statusTimeFormat: "l, NS \\o\\f F Y, G:i:s" # Status-bar's time format, see above.

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
