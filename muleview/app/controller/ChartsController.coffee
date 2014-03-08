Ext.define "Muleview.controller.ChartsController",
  extend: "Ext.app.Controller"

  requires: [
    "Muleview.model.Retention"
    "Muleview.view.MuleChart"
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
    ,
      ref: "legendButton"
      selector: "#legendButton"
    ,
      ref: "subkeysButton"
      selector: "#subkeysButton"
    ,
      ref: "refreshButton"
      selector: "#refreshButton"
    ,
      ref: "refreshCombobox",
      selector: "#refreshCombobox"
  ]

  onLaunch: ->
    @keys = []

    @chartsView = @getChartsView()
    @mainChartContainer = @getMainChartContainer()
    @retentionsMenu = @getRetentionsMenu()
    @lightChartsContainer = @getLightChartsContainer()
    @legendButton = @getLegendButton()
    @subkeysButton = @getSubkeysButton()
    @refreshButton = @getRefreshButton()
    @refreshCombobox = @getRefreshCombobox()

    Muleview.app.on
      scope: @
      viewChange: (keys, retName) ->
        @viewChange(keys, retName)
      refresh: @refresh
      legendChange: (show) ->
        Muleview.Settings.showLegend = show
        @mainChart?.setLegend(show)
        @legendButton.toggle(show)

    @retentionsStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Retention"
      sorters: ["sortValue"]
      data: []
    @retentionsMenu.bindStore(@retentionsStore)

    @legendButton.on
      scope: @
      toggle: (legendButton, pressed) ->
        Muleview.event "legendChange", pressed

    @subkeysButton.on
      scope: @
      toggle: (subkeysButton, pressed) ->
        Muleview.Settings.showSubkeys = @showSubkeys = pressed
        @renderChart()

    @refreshButton.on
      scope: @
      click: @refresh

    possibleRefreshIntervals = [
      10
      30
      60
      60 * 5
      60 * 10
      60 *15
      60 * 60
    ]
    refreshData = [["Disabled", -1]].concat([Muleview.model.Retention.toLongFormat(secs), secs] for secs in possibleRefreshIntervals)
    refreshIntervalsStore = Ext.create "Ext.data.ArrayStore",
      fields: [ "text", "value" ]
      data: refreshData

    @refreshCombobox.bindStore(refreshIntervalsStore)
    @refreshCombobox.on
      scope: @
      change: @updateRefreshTimer


    currentRefreshInterval = refreshIntervalsStore.findRecord("value", Muleview.Settings.updateInterval)
    @refreshCombobox.select(currentRefreshInterval) if currentRefreshInterval


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

  refresh: ->
    # Run the view change with the power of the force:
    @viewChange(@keys, @retention, true)

  createKeysView: (keys, retention) ->
    @mainChartContainer.removeAll()
    @lightChartsContainer.removeAll()

    # If no keys were selected, don't display anything:
    if keys.length == 0 or keys[0] == ""
      @mainChartContainer.setTitle "No graph key selected"
      @lightChartsContainer.setLoading(false)
      @mainChartContainer.setLoading(false)
      return

    @lightChartsContainer.setLoading(true)
    @mainChartContainer.setLoading(true)

    @lastRequestId = currentRequestId = Ext.id()
    Muleview.Mule.getKeysData keys, (data) =>
      # Prevent latency mess:
      return unless @lastRequestId == currentRequestId

      @updateRetentionsStore(data)
      @defaultRetention ||= @retentionsStore.getAt(0).get("name")
      @initStores(data)
      @lightChartsContainer.setLoading(false)
      @initLightCharts(data)

      if keys.length == 1
        @key = keys[0]
        @showSubkeys = Muleview.Settings.showSubkeys
        @subkeysButton.setDisabled(false)
        @mainChartContainer.setTitle @key

      else
        @showSubkeys = false
        @subkeysButton.setDisabled(true)
        @mainChartContainer.setTitle keys.join(", ")

      @subkeysButton.toggle(@showSubkeys)

      @showRetention(@defaultRetention)

  updateRetentionsStore: (data) ->
    retentions = (new Muleview.model.Retention(retName) for own retName of data)
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
    @store = @stores[retName]
    @renderChart()
    @currentRetName = retName

    @retentionsMenu.select(retName)
    for own _, lightChart of @lightCharts
      lightChart.setVisible(lightChart.retention != retName)
    @resetRefreshTimer()
    Muleview.event "viewChange", @keys, @currentRetName

  renderChart: () ->
    @mainChartContainer.removeAll()
    if @showSubkeys
      @mainChartContainer.setLoading(true)
      Muleview.Mule.getGraphData @key, @currentRetName, (data) =>
        @alerts = Ext.StoreManager.get("alertsStore").getById("#{@key};#{@currentRetName}")?.toGraphArray(@currentRetName)
        @store = @createStore(data, @alerts)
        @subkeys = Ext.Array.difference(Ext.Object.getKeys(data), [@key])
        @addChart
          showAreas: true
          topKeys: [@key]
          subKeys: @subkeys
          alerts: @alerts
          title: "#{@key};#{@currentRetName}"

    else
      @addChart
        topKeys: @keys
        title: @keys.join("<br />")

  addChart: (cfg) ->
    common = {
      flex: 1
      store: @store
      listeners:
        closed: =>
          Muleview.event "legendChange", false
    }
    @mainChartContainer.setLoading(false)
    @mainChart = (Ext.create "Muleview.view.MuleChart", Ext.apply(common, cfg))
    @mainChartContainer.insert 0, @mainChart

  updateRefreshTimer: (me, seconds) ->
    Muleview.Settings.updateInterval = seconds
    @resetRefreshTimer()

  resetRefreshTimer: ->
    window.clearInterval @refreshInterval if @refreshInterval
    seconds = Muleview.Settings.updateInterval * 1000
    return unless seconds > 0

    @refreshInterval = window.setInterval ()  =>
      @refresh()
    , seconds
