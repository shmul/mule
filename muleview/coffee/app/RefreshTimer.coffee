Ext.define "Muleview.RefreshTimer",
  requires: [
    "Muleview.Settings"
  ]
  singleton: true

  constructor: ->
    @intervalTime = Muleview.Settings.updateInterval
    Muleview.Events.on
      createGraphStart: @reset
      scope: @

  reset: ->
    window.clearTimeout(@timeout) if @timeout
    @timeout = window.setTimeout(Ext.bind(@refresh, @), @intervalTime)
    @lastRefresh = new Date()

  refresh: ->
    Muleview.Graphs.createGraphs()
