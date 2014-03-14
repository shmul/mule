Ext.define "Muleview.controller.ChartsController",
  extend: "Ext.app.Controller"

  requires: [
    "Muleview.model.Retention"
    "Muleview.view.MuleChart"
    "Muleview.view.MuleLightChart"
    "Muleview.view.AlertsEditor"
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
      ref: "alertsButton"
      selector: "#editAlertsButton"
    ,
      ref: "refreshButton"
      selector: "#refreshButton"
    ,
      ref: "refreshCombobox"
      selector: "#refreshCombobox"
    ,
      ref: "previewContainer"
      selector: "#chartPreviewContainer"
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
    @alertsButton = @getAlertsButton()
    @previewContainer = @getPreviewContainer()

    Muleview.app.on
      scope: @
      viewChange: (keys, retName) ->
        @viewChange(keys, retName)
      refresh: @refresh
      legendChange: (show) ->
        Muleview.Settings.showLegend = show
        @mainChart?.setLegend(show)
        @legendButton.toggle(show)
      mainChartZoomChange: @updateZoomStatsAndHighlight

    @retentionsStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Retention"
      sorters: ["sortValue"]
      data: []

    @retentionsMenu.on
      scope: @
      change: (combo, newValue) ->
        @viewChange @keys, newValue

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
      1
      5
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

    @alertsButton.on
      scope: @
      click: @editAlerts



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
    currentRequestId = @lastRequestId
    Muleview.Mule.getKeysData @keys, (data) =>
      return unless currentRequestId == @lastRequestId
      @fixDuplicateAndMissingTimestamps(retData) for _ret,retData of data
      for retention, lightChart of @lightCharts
        lightChart.chart.updateData(data[retention])
      if @showSubkeys
        Muleview.Mule.getGraphData @key, @retention, (data) =>
          return unless currentRequestId == @lastRequestId
          @fixDuplicateAndMissingTimestamps(data)
          @mainChart.updateData(data)
          @mainChart.updateAlerts(@getAlerts())
      else
        @mainChart.updateData(data[@retention])


  createKeysView: (keys, retention) ->
    # Remove old charts:
    @mainChartContainer.removeAll()
    @lightChartsContainer.removeAll()

    # Disable buttons:
    @alertsButton.setDisabled(true)
    @subkeysButton.setDisabled(true)

    # If no keys were selected, don't display anything:
    if keys.length == 0 or keys[0] == ""
      @mainChartContainer.setTitle "No graph key selected"
      @lightChartsContainer.setLoading(false)
      @mainChartContainer.setLoading(false)
      return

    # We're going to ask for information, let's set a load mask:
    @lightChartsContainer.setLoading("Fetching...")
    @mainChartContainer.setLoading("Fetching...")

    # Set things according to whether we're in multiple or single mode:
    singleKey = keys.length == 1
    @key = singleKey &&  keys[0]
    @mainChartContainer.setTitle keys.join(", ")

    @lastRequestId = currentRequestId = Ext.id()
    Muleview.Mule.getKeysData keys, (data) =>
      # Prevent latency mess:
      return unless @lastRequestId == currentRequestId
      for panel in [@lightChartsContainer, @mainChartContainer]
        panel.setLoading({msg: "Processing...", msgCls: "load-mask-no-image"})

      # Enable buttons:
      @showSubkeys = singleKey && Muleview.Settings.showSubkeys
      @subkeysButton.setDisabled(!singleKey)
      @subkeysButton.toggle(@showSubkeys, true)
      @alertsButton.setDisabled(!singleKey)

      # Save data - it should be retention => key => array of {x: ###, y: ###}
      @data = data
      Ext.defer =>
        return unless @lastRequestId == currentRequestId
        @updateRetentionsStore()
        @defaultRetention = @retention || @retentionsStore.getAt(0).get("name")
        @fixDuplicateAndMissingTimestamps(retData) for _ret,retData of @data
        @initLightCharts()
        @lightChartsContainer.setLoading(false)

        @showRetention(@defaultRetention)
      , 100

  updateRetentionsStore: () ->
    retentions = (new Muleview.model.Retention(retName) for own retName of @data)
    @retentionsStore.removeAll()
    @retentionsStore.loadData(retentions)

  eachRetention: (cb) ->
    @retentionsStore.each (retention) ->
      cb(retention, retention.get("name"))

  initLightCharts: () ->
    @lightCharts = {}
    @eachRetention (retention, name) =>
      @lightCharts[name] = @createLightChart(retention)
      @lightChartsContainer.add(@lightCharts[name])

  createLightChart: (retention) ->
    retName = retention.get("name")
    Ext.create "Muleview.view.MuleLightChart",
      title: retention.get("title")
      flex: 1
      topKeys: @keys
      retention: retName
      data: @data[retName]

  showRetention: (retName) ->
    @retention = retName
    @renderChart()

    @retentionsMenu.select(retName)
    for own _, lightChart of @lightCharts
      lightChart.chart.setZoomHighlight(false)
      if lightChart.retention == retName
        @currentLightChart = lightChart
        lightChart.hide()
      else
        lightChart.show()

    @resetRefreshTimer()
    Muleview.event "viewChange", @keys, @retention

  fixDuplicateAndMissingTimestamps: (data) ->
    recordsByTimestamp = {}

    for key, keyData of data
      records = recordsByTimestamp[key] = {}
      for record in keyData
        records[record.x] ||= []
        records[record.x].push(record)

      data[key] = []

    for key of data
      for timestamp, timestampRecords of recordsByTimestamp[key]
        timestampExistsInAllKeys = Ext.Array.every(Ext.Object.getKeys(data), (otherKey) -> recordsByTimestamp[otherKey][timestamp])
        if timestampExistsInAllKeys
          sum = Ext.Array.sum(Ext.Array.pluck(timestampRecords, "y"))
          average = sum / timestampRecords.length
          data[key].push {
            x: parseInt(timestamp),
            y: average
          }

  getAlerts: () ->
    Ext.StoreManager.get("alertsStore").getById("#{@key};#{@retention}")?.toGraphArray(@retention)

  renderChart: () ->
    @mainChartContainer.removeAll()
    if @showSubkeys
      @mainChartContainer.setLoading(true)
      Muleview.Mule.getGraphData @key, @retention, (data) =>
        @alerts = @getAlerts()
        @subkeys = Ext.Array.difference(Ext.Object.getKeys(data), [@key])
        @addChart
          showAreas: true
          topKeys: [@key]
          subKeys: @subkeys
          alerts: @alerts
          data: data

    else
      @addChart
        topKeys: @keys
        data: @data[@retention]

  addChart: (cfg) ->
    @fixDuplicateAndMissingTimestamps(cfg.data)
    common = {
      flex: 1
      title: ("#{key};#{@retention}" for key in @keys).join("<br />")
      listeners:
        closed: =>
          Muleview.event "legendChange", false
    }
    @mainChartContainer.setLoading(false)
    cfg = Ext.apply({}, cfg, common)
    @mainChart = (Ext.create "Muleview.view.MuleChart", cfg)
    @mainChartContainer.removeAll()
    @mainChartContainer.add @mainChart
    @previewContainer.removeAll()
    preview = Ext.create "Muleview.view.Preview",
      previewGraph: @lightCharts[@retention].chart.graph
      zoomGraph: @mainChart.graph
    @previewContainer.add preview



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

  editAlerts: ->
    ae = Ext.create "Muleview.view.AlertsEditor",
      key: @key
      retention: @retention
      data: @data[@retention][@key]
    ae.show()

  updateZoomStatsAndHighlight: (timestampMin, timestampMax) ->
    #Highlight:
    @currentLightChart.chart.setZoomHighlight(true, timestampMin, timestampMax)

    # Stats:
    min = null
    max = null
    last = null
    sum = 0
    count = 0

    data = @data[@retention]
    firstKey = data[@keys[0]]

    # I'm assuming all keys have the same x values
    index = 0
    timestamp = firstKey[0].x

    until timestamp  >= timestampMin or index == firstKey.length
      timestamp = firstKey[index].x
      index += 1

    while timestamp <= timestampMax and index < firstKey.length
      count += 1
      value = 0
      for key in @keys
        value += data[key][index].y

      min ||= value
      max ||= value

      sum += value
      min = Math.min(min, value)
      max = Math.max(min, value)
      last = value

      index += 1
      timestamp = firstKey[index].x if index < firstKey.length

    stats =
      min: min
      max: max
      average: sum / count
      last: last
      count: count
      size: firstKey.length
    Muleview.event "statsChange", stats
