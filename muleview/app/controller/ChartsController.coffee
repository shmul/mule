Ext.define "Muleview.controller.ChartsController",
  extend: "Ext.app.Controller"
  refs: [
      ref: "ChartsViewContainer"
      selector: "#chartsViewContainer"
  ]

  onLaunch: ->
    @chartsViewContainer = @getChartsViewContainer()
    Muleview.app.on
      scope: @
      viewChange: (key, retName)->
        @viewChange(key, retName)
      refresh: @refresh

  viewChange: (key, retention, force) ->
    if key != @key or force
      @key = key
      @createKeyView(key, retention || @retention)

    else if @retention != retention
      @chartsView.showRetention(retention)
      @retention = retention

  refresh: ->
    @viewChange(@key, @retention, true)

  createKeyView: (key, retention) ->
    @chartsViewContainer.removeAll()
    @chartsViewContainer.setLoading(true)
    Muleview.Mule.getKeyData key, (keyData, alerts) =>
      @chartsView = @getView("ChartsView").create
        key: key
        data: keyData
        alerts: alerts
        defaultRetention: retention
      @chartsViewContainer.add(@chartsView)
      @chartsViewContainer.setLoading(false)
      @chartsViewContainer.setTitle(key.replace(/\./, " / "))
