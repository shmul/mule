Ext.define "Muleview.RefreshTimer",
  singleton: true

  constructor: ->
    @intervalTime = Muleview.Settings.updateInterval
    Muleview.Events.on
      createGraphStart: @reset
      scope: @

  reset: ->
    window.clearTimeout(@timeout) if @timeout
    @timeout = window.setTimeout(Ext.bind(@refresh, @), @intervalTime)

  refresh: ->
    Muleview.Graphs.createGraphs()
