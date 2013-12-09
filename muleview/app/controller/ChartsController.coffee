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
      @retention = retention if retention

      # If we have new keys, we completely replace the current ChartsView with a new one:
      @createKeysView(keys, retention || @retention)

    else if @retention != retention
      # If only the retention was changed, we ask the ChartsView to show the new one:
      @retention = retention
      @chartsView?.showRetention(retention)

  refresh: ->
    # Run the view change with the power of the force:
    @viewChange(@keys, @retention, true)

  createKeysView: (keys, retention) ->
    # Remove old view
    @chartsViewContainer.removeAll()

    # If no keys were selected, don't display anything:
    if keys.length == 0 or keys[0] == ""
      @chartsView = null
      return

    # If some keys were selected, set a loading mask before retreiving them:
    @chartsView = @createChartsView(keys, retention)

    # Add the new ChartsView to its container and remove loading mask:
    @chartsViewContainer.add(@chartsView)

    if keys.length == 1
      # Set a nice title to the panel, replacing "." with "/":
      @chartsViewContainer.setTitle keys[0]
    else
      @chartsViewContainer.setTitle("Comparison Mode") #FIXME

  createChartsView: (keys, retention) ->
    if keys.length == 1
      ans = @getView("SingleGraphChartsView").create
        key: keys[0]
        defaultRetention: retention

    else if keys.length > 1
      ans = @getView("ChartsView").create
        keys: keys
        defaultRetention: retention
    ans
