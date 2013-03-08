Ext.define "Muleview.Settings",
  singleton: true
  updateInterval: 5000
  labelFormat: "d/m/y H:i:s"
  muleUrlPrefix: "http://localhost:3000/"
  statusTimeFormat: "l, NS \\o\\f F Y, G:i:s"
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
