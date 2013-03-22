Ext.define "Muleview.RefreshTimer",
  singleton: true

  requires: [
    "Muleview.Events"
    "Muleview.Settings"
  ]

  constructor: ->
    window.setInterval =>
      Muleview.event "refreshRequest"
    , Muleview.Settings.updateInterval
