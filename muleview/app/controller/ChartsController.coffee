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
        alerts: @processAlerts(alerts)
        defaultRetention: retention
      @chartsViewContainer.add(@chartsView)
      @chartsViewContainer.setLoading(false)
      @chartsViewContainer.setTitle(key.replace(/\./, " / "))

  # Preprocess Mule's alerts array according to Muleview.Settings.alerts
  # From:
  #  {
  #    "mykey;1m:1h": [0,1,100,250, 60, 60],
  #    "mykey;1d:3y": [0,10,200,350, 60, 360],
  #   ...
  #  }
  # To:
  # {
  #   "mykey;1m:1h": [
  #     {name: "critical_low", label: "Critical Low", value: 0, ...},
  #     {name: "warning_low", label: "Warning Low", value: 1, ...},
  #     ...
  #     ],
  #  "mykey;1d:3y": [
  #    {name: "critical_low", ... ],
  #    ...
  # }

  processAlerts: (rawAlertsHash) ->
    ans = {}
    for own retName, rawArr of rawAlertsHash
      ans[retName] = (Ext.apply {}, obj, {value: rawArr.shift()} for obj in Muleview.Settings.alerts)
    ans