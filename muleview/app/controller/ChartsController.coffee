Ext.define "Muleview.controller.ChartsController",
  extend: "Ext.app.Controller"

  requires: [
    "Muleview.model.Retention"
    "Muleview.view.MuleLightChart"
  ]

  refs: [
      ref: "ChartsView"
      selector: "#chartsView"
    ,
      ref: "mainChartContainer"
      selector: "#mainChartContainer"
    ,
      ref: "retentionsMenu"
      selector: "#retentionsMenu"
    ,
      ref: "lightChartsContainer"
      selector: "#lightChartsContainer"
  ]

  onLaunch: ->
    @keys = []

    @chartsView = @getChartsView()
    @mainChartContainer = @getMainChartContainer()
    @retentionsMenu = @getRetentionsMenu()
    @lightChartsContainer = @getLightChartsContainer()

    Muleview.app.on
      scope: @
      viewChange: (keys, retName)->
        @viewChange(keys, retName)
      refresh: @refresh

    @retentionsStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Retention"
      sorters: ["sortValue"]
      data: []
    @retentionsMenu.bindStore(@retentionsStore)


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
      @showRetention(retention)

  showRetention: (ret) ->
    console.log('ChartsController.coffee\\ 43: ret:', ret);
    #TODO...

  refresh: ->
    # Run the view change with the power of the force:
    @viewChange(@keys, @retention, true)

  createKeysView: (keys, retention) ->
    @lightChartsContainer.removeAll()

    # If no keys were selected, don't display anything:
    if keys.length == 0 or keys[0] == ""
      @noKeys()
    else if keys.length == 1
      @singleKey(keys[0], retention)
    else
      @multipleKeys(keys, retention)

  noKeys: () ->
    @mainChartContainer.setTitle "No graph key selected"

  singleKey: (key, retention) ->
    @mainChartContainer.setTitle key
    Muleview.Mule.getKeysData [key], (keysData) =>
      @fillRetentionsAndLightCharts(keysData)


  multipleKeys: (keys, retention) ->
    @mainChartContainer.setTitle keys.join(", ")

# ================================================================

  fillRetentionsAndLightCharts: (data) ->
    console.log('ChartsController.coffee\\ 91: data:', data);
    @updateRetentionsStore(data)
    console.log("ChartsController.coffee\\ 93: <HERE>");
    @defaultRetention ||= @retentionsStore.getAt(0).get("name")
    @initStores(data)
    @initLightCharts(data)
    @showRetention(@defaultRetention)

  updateRetentionsStore: (data) ->
    retentions = (new Muleview.model.Retention(retName) for own retName of data)
    console.log('ChartsController.coffee\\ 105: retentions:', retentions);
    @retentionsStore.removeAll()
    @retentionsStore.loadData(retentions)

  eachRetention: (cb) ->
    @retentionsStore.each (retention) ->
      cb(retention, retention.get("name"))

  initStores: (data) ->
    @stores = {}
    @eachRetention (retention, name) =>
      @stores[name] = @createStore(data[name])

  # Creates a flat store from a hash of {
  #   key1 => [[count, batch, timestamp], ...],
  #   key2 => [[count, batch, timestamp], ...]
  # }
  createStore: (data, alerts = []) ->
    #TODO: check if alerts is till necessary here
    fields = []
    addField = (name) ->
      fields.push
        name: name
        type: "integer"

    # Create initial store:
    addField "timestamp"
    addField key for key, _ of data
    addField alert.name for alert in alerts

    store = Ext.create "Ext.data.ArrayStore",
      fields: fields
      sorters: [
          property: "timestamp"
      ]

    # Convert data to timestamps-based hash:
    window.d = data
    timestamps = {}
    for own key, keyData of data
      for [count, _, timestamp] in keyData
        unless timestamps[timestamp]
          timestamps[timestamp] = {
            timestamp: timestamp
          }
          timestamps[timestamp][alert.name] = alert.value for alert in alerts if alerts
        timestamps[timestamp][key] = count

    # Add the data:
    store.add(Ext.Object.getValues(timestamps))
    store

  initLightCharts: (data) ->
    @lightCharts = {}
    @eachRetention (retention, name) =>
      @lightCharts[name] = @createLightChart(retention, data)
      @lightChartsContainer.add(@lightCharts[name])

  createLightChart: (retention, data) ->
    retName = retention.get("name")
    Ext.create "Muleview.view.MuleLightChart",
      title: retention.get("title")
      flex: 1
      topKeys: @keys
      hidden: true
      retention: retName
      store: @stores[retName]

  showRetention: (retName) ->
    # Be oh-so-idempotent:
    return unless !@currentRetName or(retName and retName != @currentRetName)

    retName ||= @retentionsStore.getAt(0).get("name")
    # @chartContainer.setLoading(true)
    # @createChart(retName)
    @retentionsMenu.select(retName)
    for own _, lightChart of @lightCharts
      lightChart.setVisible(lightChart.retention != retName)
    @currentRetName = retName
    Muleview.event "viewChange", @keys, @currentRetName

  ################################################################

  updateRefreshTimer: (me, seconds) ->
    Muleview.Settings.updateInterval = seconds
    window.clearInterval @refreshInterval if @refreshInterval
    return unless seconds > 0
    @refreshInterval = window.setInterval ()  =>
      if not me.getEl() # Hack: Don't refresh if the container has been replaced
        window.clearInterval @refreshInterval
        return
      @refresh()
    , Muleview.Settings.updateInterval * 1000

  createRetentionsMenu: ->
    clickHandler = (me) =>
      # We make sure the retention checkbox is checked before raising an event,
      # because Extjs causes previously-checked buttons to invoke their own click event upon "implicitly" getting unchecked
      # (as a result of a different checkbox getting checked)
      Muleview.event "viewChange", @keys, me.retention.get("name") if me.checked

    items = []
    @retentionsStore.each (ret) =>
      return unless ret
      item = Ext.create "Ext.menu.CheckItem",
        text: ret.get("title")
        retention: ret
        group: "retention"
        checkHandler: clickHandler
        showCheckbox: false

      ret.menuItem = item
      items.push item

    Ext.create "Ext.button.Button",
      selectRetention: (retName) ->
        for item in items
          selected = item.retention.get("name") == retName
          item.setChecked(selected, true) # true to suppress events
          @setText(item.retention.get("title")) if selected
      menu:
        items: items


  createChart: (retName = @currentRetName) ->
    @store = @stores[retName]
    @renderChart()


  renderChart: () ->
    @chartContainer.removeAll()
    @chart = Ext.create "Muleview.view.MuleChart",
      flex: 1
      topKeys: @keys
      store: @store
      listeners:
        closed: =>
          @legendClosed()

    @chartContainer.insert 0, @chart
    @chartContainer.setLoading(false)


  legendClosed: ->
    @legendButton.toggle(false)
    Muleview.Settings.showLegend = false
