Ext.define "Muleview.controller.ChartsController",
  extend: "Ext.app.Controller"

  requires: [
    "Muleview.view.SingleGraphChartsView"
  ]

  refs: [
      ref: "ChartsViewContainer"
      selector: "#chartsViewContainer"
  ]

  onLaunch: ->
    @keys = []
    @chartsViewContainer = @getChartsViewContainer()
    Muleview.app.on
      scope: @
      viewChange: (keys, retName)->
        @viewChange(keys, retName)
      refresh: @refresh

  viewChange: (keys, retention, force) ->
    # If given a string for keys, convert it to an array:
    keys = keys.split(",") if Ext.isString(keys)

    # Check if any keys were changed from the previous rendering:
    difference = @keys.length != keys.length || Ext.Array.difference(@keys, keys).length != 0

    # Create or update the ChartsView object:
    if difference or force
      @keys = Ext.clone(keys)  # Must clone due to mysterious bug causing multiple keys to reduce to the just the first one.

      # If we have new keys, we completely replace the current ChartsView with a new one:
      @createKeysView(keys, retention || @retention)

    else if @retention != retention
      # If only the retention was changed, we ask the ChartsView to show the new one:
      @retention = retention
      @chartsView.showRetention(retention)

  refresh: ->
    # Run the view change with the power of the force:
    @viewChange(@keys, @retention, true)

  createKeysView: (keys, retention) ->
    # Remove old view
    @chartsViewContainer.removeAll()

    # If no keys were selected, don't display anything:
    if keys.length == 0
      @chartsView = null
      return

    # If some keys were selected, set a loading mask before retreiving them:
    @chartsViewContainer.setLoading(true)
    Muleview.Mule.getKeysData keys, (keysData, alerts) =>
      @chartsView = @createChartsView(keys, retention, keysData, alerts)
      @chartsView.showRetention(retention)
      # Add the new ChartsView to its container and remove loading mask:
      @chartsViewContainer.add(@chartsView)
      @chartsViewContainer.setLoading(false)

      if keys.length == 1
        # Set a nice title to the panel, replacing "." with "/":
        @chartsViewContainer.setTitle(keys[0].replace(/\./, " / "))
      else
        @chartsViewContainer.setTitle("Comparison Mode") #FIXME

  createChartsView: (keys, retention, keysData, alerts) ->
    if keys.length == 1
      ans = @getView("SingleGraphChartsView").create
        key: keys[0]
        data: keysData
        alerts: @processAlerts(alerts)
        defaultRetention: retention

    else if keys.length > 1
      ans = @getView("ChartsView").create
        topKeys: keys
        data: keysData
        defaultRetention: retention
    ans


  processAlerts: (rawAlertsHash) ->
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
    ans = {}
    for own retName, rawArr of rawAlertsHash
      ans[retName] = (Ext.apply {}, obj, {value: rawArr.shift()} for obj in Muleview.Settings.alerts)
    ans
