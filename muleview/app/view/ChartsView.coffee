Ext.define "Muleview.view.ChartsView",
  extend: "Ext.panel.Panel"
  requires: [
    "Ext.form.field.ComboBox"
    "Muleview.model.Retention"
    "Muleview.view.MuleChartPanel"
    "Muleview.view.MuleLightChart"
    "Ext.data.ArrayStore"
  ]
  header: false
  layout: "border"
  showLegend: true
  othersKey: Muleview.Settings.othersSubkeyName # Will be used as the name for the key which will group all hidden subkeys

  alerts: []

  initRetentions: ->
    # Init retentions (these are just the names, for the combo box)
    retentions = (new Muleview.model.Retention(retName) for own retName of @data)
    @retentionsStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Retention"
      sorters: ["sortValue"]
      data: retentions
    @defaultRetention ||= @retentionsStore.getAt(0).get("name")

  initKeys: ->
    @keys = Ext.Object.getKeys(@data[@defaultRetention])

  eachRetention: (cb) ->
    @retentionsStore.each (retention) ->
      cb(retention, retention.get("name"))

  initStores: ->
    @stores = {}
    @eachRetention (retention, name) =>
      @stores[name] = @createStore(name)

  initLightCharts: ->
    @lightCharts = {}
    @eachRetention (retention, name) =>
      @lightCharts[name] = @createLightChart(retention)

  initComponent: ->
    @initRetentions()
    @initKeys()

    # Create all stores and light charts:
    @initStores()
    @initLightCharts()

    # Init component:
    @items = @items()
    @callParent()
    @eachRetention (retention, name) =>
      @rightPanel.add(@lightCharts[name])

  items: ->
    [
        @chartContainer = Ext.create "Ext.panel.Panel",
          region: "center"
          header: false
          layout:
            type: "vbox"
            align: "stretch"
          tbar: @createChartContainerToolbar()
      ,
        @rightPanel = Ext.create "Ext.panel.Panel",
          title: "Previews"
          cls: "rightPanel"
          region: "east"
          split: true
          width: "20%"
          collapsible: true
          layout:
            type: "vbox"
            align: "stretch"
          items: @lightCharts
    ]

  createChartContainerToolbar: ->
    [
        "Show:"
      ,
        @retMenu = @createRetentionsMenu()
      , "-",
        xtype: "button"
        text: "Refresh"
        icon: "resources/default/images/refresh.png"
        handler: ->
          Muleview.event "refresh"
      , "-",
        text: "Hide Legend"
        icon: "resources/default/images/legend.png"
        enableToggle: true
        pressed: !@showLegend
        toggleHandler: (me, value) =>
          @showLegend = !value
          @renderChart()

    ]

  createRetentionsMenu: ->
    clickHandler = (me) =>
      Muleview.event "viewChange", @topKeys, me.retention.get("name")

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
          item.setChecked(selected)
          @setText(item.retention.get("title")) if selected
      menu:
        items: items

  showRetention: (retName) ->
    return unless !@currentRetName or(retName and retName != @currentRetName)
    retName ||= @retentionsStore.getAt(0).get("name")
    @renderChart(retName)
    @retMenu.selectRetention(retName)

    lightChart.setVisible(lightChart.retention != retName) for own _, lightChart of @lightCharts
    @currentRetName = retName
    Muleview.event "viewChange", @topKeys, @currentRetName

  renderChart: (retName = @currentRetName) ->
    @chartContainer.removeAll()
    store = @stores[retName]
    @chartContainer.add Ext.create "Muleview.view.MuleChart",
      flex: 1
      topKeys: @topKeys
      store: store
      showLegend: @showLegend
    @chartContainer.add Ext.create "Muleview.view.ZoomSlider",
      store: store

  # Creates a flat store from a hash of {
  #   key1 => [[count, batch, timestamp], ...],
  #   key2 => [[count, batch, timestamp], ...]
  # }
  createStore: (retName) ->
    # Create initial store:
    alerts = @alerts[retName]
    store = @createEmptyStore(alerts)
    # Convert data to timestamps-based hash:
    timestamps = {}
    for own key, keyData of @data[retName]
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

  createEmptyStore: (alerts) ->
    # Initialize store:
    fields = (name: key, type: "integer" for key in @keys)
    fields.push(name: "timestamp", type: "integer")
    fields.push {name: alert.name, type: "integer"} for alert in alerts if alerts

    store = Ext.create "Ext.data.ArrayStore",
      fields: fields
      sorters: [
          property: "timestamp"
      ]

  createLightChart: (retention) ->
    retName = retention.get("name")
    Ext.create "Muleview.view.MuleLightChart",
      title: retention.get("title")
      flex: 1
      topKeys: @topKeys
      hidden: true
      retention: retName
      store: @stores[retName]
