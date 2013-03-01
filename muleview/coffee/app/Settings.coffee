Ext.define "Muleview.Settings",
  singleton: true
  updateInterval: 1000
  labelFormat: "d/m/y H:i:s"
  alerts: [
      name: "critical_low"
      label: "Critical Low"
    ,
      name: "warning_low"
      label: "Warning Low"
    ,
      name: "warning_high"
      label: "Warning High"
    ,
      name: "critical_high"
      label: "Critical High"

    # ,
    #   name: "stale"
    #   label: "Stale"
    #   time: true
    # ,
    #   name: "period"
    #   label: "Period"
    #   time: true
  ]
