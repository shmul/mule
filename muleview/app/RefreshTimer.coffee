Ext.define "Muleview.RefreshTimer",
  singleton: true

  requires: [
    "Muleview.Settings"
  ]

  constructor: ->
    window.setInterval =>
      Muleview.event "refreshRequest"
    , Muleview.Settings.updateInterval
