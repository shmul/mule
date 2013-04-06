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
      viewChange: @viewChange

  viewChange: (key, retention) ->
    olderKey = @key
    olderRetention = @retention
    @key = key
    @retention = retention
    if @key != olderKey
      @createKeyView(key, retention)
    else if @retention != olderRetention
      @chartsView.showRetention(retention)

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
