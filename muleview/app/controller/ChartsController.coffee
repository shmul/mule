Ext.define "Muleview.controller.ChartsController",
  extend: "Ext.app.Controller"

  requires: [
    "Muleview.model.Retention"
    "Muleview.view.MuleChart"
    "Muleview.view.MuleLightChart"
    "Muleview.view.AlertsEditor"
    "Muleview.view.PieChart"
    "Muleview.view.Preview"
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
      ref: "showAnomaliesButton"
      selector: "#showAnomaliesButton"
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
    ,
      ref: "restoreButton"
      selector: "#mainChartToolRestore"
    ,
      ref: "maximizeButton"
      selector: "#mainChartToolMaximize"
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
    @toolbar = @mainChartContainer.getDockedComponent(1)
    @restoreButton = @getRestoreButton()
    @maximizeButton = @getMaximizeButton()
    @statePanels = [
        panel: Ext.getCmp("leftPanel"),
      ,
        panel: Ext.getCmp("alertsReport")
      ,
        panel:@lightChartsContainer
    ]

    Muleview.app.on
      scope: @
      viewChange: (keys, retName) ->
        @viewChange(keys, retName)
      refresh: @refresh
      legendChange: (show) ->
        Muleview.Settings.showLegend = show
        @mainChart?.setLegend(show)
        @legendButton.toggle(show)
      mainChartZoomChange: @updateZoomStats
      topkeyclick: (chart, type, point, event) =>
        return unless point and chart == @mainChart
        key = point.series.key
        retention = chart.retention
        if type == "topkey"
          pieChartWindow = Ext.create "Muleview.view.PieChart",
            key: key
            retention: retention
            timestamp: point.value.x
            value: point.value.y
            formattedTimestamp:  point.formattedXValue
          pieChartWindow.show()
        else if type == "subkey"
          Muleview.event "viewchange", key, retention



    @mainChartContainer.getHeader().on
      scope: @
      dblclick: @togglePanelState


    for panel in @statePanels
      panel.panel.on
        scope: @
        expand: @updateStateButtons
        collapse: @updateStateButtons

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

    @getShowAnomaliesButton().on
      scope: @
      click: (me) ->
        Muleview.Settings.showAnomalies = me.pressed
        @redrawChart()


    @subkeysButton.on
      scope: @
      toggle: (subkeysButton, pressed) ->
        Muleview.Settings.showSubkeys = @showSubkeys = pressed
        @showRetention(@retention)

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

    @maximizeButton.on
      scope: @
      click: @maximizeMainChartPanel

    @restoreButton.on
      scope: @
      click: @restoreMainChartPanel
    @updateStateButtons()
    @showNoData()

  redrawChart: ->
    #TODO: just redraw, not complete refresh
    @viewChange(@keys, @retention, true)

  viewChange: (keys, retention, forceUpdate) ->
    keys = keys.split(",") if Ext.isString(keys)
    keysWereChanged = @keys.length != keys.length || Ext.Array.difference(@keys, keys).length != 0
    retentionWasChanged = @retention != retention

    if keysWereChanged or forceUpdate
      @keys = Ext.clone(keys)  # Must clone due to mysterious bug causing multiple keys to reduce to the just the first one.
      @retention = retention if retention
      @currentViewId = Ext.id()
      @createKeysView()

    else if retentionWasChanged
      @retention = retention
      @currentViewId = Ext.id()
      @showRetention(retention)

  safeCallback: (cb) ->
    # Return a callback that will not execute if the current view
      # (either keys or retention) has changed)
    viewId = @currentViewId
    () =>
      cb.apply(@, arguments) if @currentViewId == viewId

  refresh: ->
    @refreshButton.setProgress(true)
    Muleview.Mule.getKeysData @keys, @safeCallback((data) =>
      @fixDuplicateAndMissingTimestamps(retData) for _ret,retData of data
      for retention, lightChart of @lightCharts
        lightChart.chart.updateData(data[retention])
      if @showSubkeys
        # I'm doing the 2nd async request after the 1st one's response
          # because of some funky Mule behaviour
        Muleview.Mule.getGraphData @key, @retention, @safeCallback((data) =>
          @fixDuplicateAndMissingTimestamps(data, false)
          @mainChart.updateData(data)
          @refreshButton.setProgress(false)
        )
      else
        @mainChart.updateData(data[@retention])
        @refreshButton.setProgress(false)
    )

  showNoData: () ->
      @mainChartContainer.setTitle "No Key Selected"
      @toolbar.setDisabled(true)
      panel.setLoading(false) for panel in [@lightChartsContainer, @mainChartContainer, @previewContainer]
      @previewContainer.hide()

  createKeysView: () ->
    @mainChartContainer.removeAll()
    @lightChartsContainer.removeAll()
    @previewContainer.removeAll()

    @alertsButton.setDisabled(true)
    @subkeysButton.setDisabled(true)

    @previewContainer.hide()

    # If no keys were selected, don't display anything:
    if @keys.length == 0 or @keys[0] == ""
      @showNoData()
      return

    # Masking
    @lightChartsContainer.setLoading("Fetching...")
    @mainChartContainer.setLoading("Fetching...")
    @toolbar.setDisabled(false)

    # Multi or single mode?
    singleKey = @keys.length == 1
    @key = singleKey &&  @keys[0]
    @mainChartContainer.setTitle @keys.join(", ")

    viewId = @currentViewId
    Muleview.Mule.getKeysData @keys, @safeCallback((data) =>
      # data should be retention => key => array of {x: ###, y: ###}
      @data = data


      # Enable buttons:
      @showSubkeys = singleKey && Muleview.Settings.showSubkeys
      @subkeysButton.setDisabled(!singleKey)
      @subkeysButton.toggle(@showSubkeys, true)
      @alertsButton.setDisabled(!singleKey)

      @lightChartsContainer.setLoading({msg: "Processing...", msgCls: "load-mask-no-image"})
      @mainChartContainer.setLoading({msg: "Processing...", msgCls: "load-mask-no-image"})

      # Defer the processing to have the masking properly displayed:
      Ext.defer @safeCallback( =>
        @updateRetentionsStore()
        defaultRetention = @retention
        defaultRetention = @retentionsStore.getAt(0).get("name") unless @retentionsStore.findExact("name", defaultRetention) > -1
        @fixDuplicateAndMissingTimestamps(retData) for _ret,retData of @data
        @initLightCharts()
        @lightChartsContainer.setLoading(false)

        @showRetention(defaultRetention)
      ), 100
    )

  updateRetentionsStore: () ->
    retentions = (new Muleview.model.Retention(retName) for own retName of @data)
    @retentionsStore.removeAll()
    @retentionsStore.loadData(retentions)

  initLightCharts: () ->
    @lightCharts = {}
    @retentionsStore.each (retention) =>
      name = retention.get("name")
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

    @mainChartContainer.removeAll()
    @previewContainer.hide()
    @previewContainer.removeAll()

    @retentionsMenu.select(retName)
    for own _, lightChart of @lightCharts
      if lightChart.retention == retName
        @currentLightChart = lightChart
        lightChart.hide()
      else
        lightChart.show()

    if @showSubkeys
      @mainChartContainer.setLoading({msg: "Fetching Subkeys..."})
      Muleview.Mule.getGraphData @key, @retention, @safeCallback((data) =>
        @subkeys = Ext.Array.difference(Ext.Object.getKeys(data), [@key])
        @addChart
          showAreas: true
          topKeys: [@key]
          subKeys: @subkeys
          interpolation: "step-after"
          data: data
      )

    else
      @addChart
        topKeys: @keys
        data: @data[@retention]

  fixDuplicateAndMissingTimestamps: (data, omitMissingKeys = true) ->
    recordsByTimestamp = {}
    allKeys = Ext.Object.getKeys(data)

    for key, keyData of data
      records = recordsByTimestamp[key] = {}
      for record in keyData
        records[record.x] ||= []
        records[record.x].push(record)
      data[key] = []

    if !omitMissingKeys
      for key in allKeys
        for timestamp, _ of recordsByTimestamp[key]
          for otherKey in allKeys
            recordsByTimestamp[otherKey][timestamp] ||= []

    for key in allKeys
      for timestamp, timestampRecords of recordsByTimestamp[key]
        if !omitMissingKeys || Ext.Array.every(allKeys, (otherKey) -> recordsByTimestamp[otherKey][timestamp])
          sum = Ext.Array.sum(Ext.Array.pluck(timestampRecords, "y"))
          average = sum / timestampRecords.length || 0
          data[key].push {
            x: parseInt(timestamp),
            y: average
          }

  getAlerts: () ->
    Ext.StoreManager.get("alertsStore").getById("#{@key};#{@retention}")?.toGraphArray(@retention)

  addChart: (cfg) ->
    @fixDuplicateAndMissingTimestamps(cfg.data, !@showSubkeys)
    common = {
      flex: 1
      alerts: @getAlerts()
      title: ("#{key};#{@retention}" for key in @keys).join("<br />")
      retention: @retention
      listeners:
        closed: =>
          Muleview.event "legendChange", false
    }
    cfg = Ext.apply({}, cfg, common)
    @mainChart = (Ext.create "Muleview.view.MuleChart", cfg)
    @mainChartContainer.removeAll()
    @mainChartContainer.add @mainChart

    @mainChartContainer.setLoading(false)

    @previewContainer.removeAll()
    @previewContainer.add(Ext.create("Muleview.view.Preview",
      mainChart: @mainChart
      lightChart: @lightCharts[@retention])
    )
    @previewContainer.show()
    @resetRefreshTimer()
    Muleview.event "viewChange", @keys, @retention

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

  updateZoomStats: (timestampMin, timestampMax) ->
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

  togglePanelState: () ->
    doRestore = true
    for panel in @statePanels
      doRestore &&= panel.panel.getCollapsed()
    if doRestore then @restoreMainChartPanel() else @maximizeMainChartPanel()


  updateStateButtons: () ->
    buttonToShow = "restore"
    for panel in @statePanels
      buttonToShow = "maximize" if !panel.panel.getCollapsed()
    @showStateButtons(buttonToShow)

  showStateButtons: (buttonToShow) ->
    if buttonToShow == "restore"
      @restoreButton.show()
      @maximizeButton.hide()
    else if buttonToShow == "maximize"
      @restoreButton.hide()
      @maximizeButton.show()
    else
      throw "Invalid state button to show: #{buttonToShow}"

  maximizeMainChartPanel: ()->
    for panel in @statePanels
      panel.expand = ! panel.panel.getCollapsed()
      panel.panel.collapse()
    @showStateButtons("restore")

  restoreMainChartPanel: ()->
    for panel in @statePanels
      panel.panel.expand() if panel.expand
    @showStateButtons("maximize")
