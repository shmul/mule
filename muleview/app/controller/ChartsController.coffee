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
    @alertsButton = @getAlertsButton()

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
    # Run the view change with the power of the force:
    @viewChange(@keys, @currentRetName, true)

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
    @lightChartsContainer.setLoading(true)
    @mainChartContainer.setLoading(true)

    # Set things according to whether we're in multiple or single mode:
    singleKey = keys.length == 1
    @key = singleKey &&  keys[0]
    @mainChartContainer.setTitle keys.join(", ")

    @lastRequestId = currentRequestId = Ext.id()
    Muleview.Mule.getKeysData keys, (data) =>
      # Prevent latency mess:
      return unless @lastRequestId == currentRequestId

      # Enable buttons:
      @showSubkeys = singleKey && Muleview.Settings.showSubkeys
      @subkeysButton.setDisabled(!singleKey)
      @subkeysButton.toggle(@showSubkeys)
      @alertsButton.setDisabled(!singleKey)


      # Save data - it should be retention => key => array of {x: ###, y: ###}
      @data = data

      @updateRetentionsStore()
      @defaultRetention = @currentRetName || @retentionsStore.getAt(0).get("name")

      @initLightCharts()
      @lightChartsContainer.setLoading(false)

      @showRetention(@defaultRetention)

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
    @currentRetName = retName
    @renderChart()

    @retentionsMenu.select(retName)
    for own _, lightChart of @lightCharts
      lightChart.chart.setZoomHighlight(false)
      @currentLightChart = lightChart if lightChart.retention == retName

    @resetRefreshTimer()
    Muleview.event "viewChange", @keys, @currentRetName

  renderChart: () ->
    @mainChartContainer.removeAll()
    if @showSubkeys
      @mainChartContainer.setLoading(true)
      Muleview.Mule.getGraphData @key, @currentRetName, (data) =>
        @alerts = Ext.StoreManager.get("alertsStore").getById("#{@key};#{@currentRetName}")?.toGraphArray(@currentRetName)
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
        data: @data[@currentRetName]

  addChart: (cfg) ->
    common = {
      flex: 1
      title: ("#{key};#{@currentRetName}" for key in @keys).join("<br />")
      listeners:
        closed: =>
          Muleview.event "legendChange", false
    }
    @mainChartContainer.setLoading(false)
    cfg = Ext.apply({}, cfg, common)
    @mainChart = (Ext.create "Muleview.view.MuleChart", cfg)
    @mainChartContainer.removeAll()
    @mainChartContainer.add @mainChart

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
      retention: @currentRetName
      data: @data[@curretRetName] #TODO: FIX ME
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

    data = @data[@currentRetName]
    firstKey = data[@keys[0]]

    # I'm assuming all keys have the same x values
    index = 0
    timestamp = firstKey[0].x

    until timestamp  >= timestampMin or index == firstKey.length
      index += 1
      timestamp = firstKey[index].x

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
    Muleview.event "statsChange", stats
