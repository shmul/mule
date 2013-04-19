Ext.define "Muleview.view.ChartsView",
  extend: "Ext.panel.Panel"
  alias: "widget.chartsview"
  requires: [
    "Ext.form.field.ComboBox"
    "Muleview.model.Retention"
    "Muleview.view.MuleChartPanel"
    "Muleview.view.MuleLightChart"
    "Ext.data.ArrayStore"
    "Muleview.store.SubkeysStore"
    "Muleview.view.SubkeysSelector"
    "Muleview.view.AlertsEditor"
  ]
  header: false
  layout: "border"
  othersKey: Muleview.Settings.othersSubkeyName

  showLegend: true # default

  # Replace full Mule key names as keys with retention-name only
  processAlertsHash: (alerts) ->
    ans = {}
    for own k, v of alerts
      [muleKey, ret] = k.split(";")
      ans[ret] = v if muleKey == @key
    ans

  initComponent: ->
    # Init retentions (these are just the names, for the combo box)
    retentions = (new Muleview.model.Retention(retName) for own retName of @data)
    @retentionsStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Retention"
      sorters: ["sortValue"]
      data: retentions

    @defaultRetention ||= @retentionsStore.getAt(0).get("name")
    @keys = Ext.Object.getKeys(@data[@defaultRetention])

    @subkeys = Ext.clone(@keys)
    Ext.Array.remove(@subkeys, @key)
    @keys.push(@othersKey) # Need to add othersKey as a key so that the records will have such an attribute

    # Rename alerts' keys to be hashed only by the retName
    @alerts = @processAlertsHash(@alerts)

    # Create all stores and light charts:
    @stores = {}
    @lightCharts = {}
    @retentionsStore.each (retention) =>
      name = retention.get("name")
      @stores[name] = @createStore(name)
      @lightCharts[name] = @createLightChart(retention)

    # Init the subkeys-store to calculate which subkeys its best to show first:
    @subkeysStore = Ext.create "Muleview.store.SubkeysStore",
      dataStore: @stores[@defaultRetention]
    @subkeysStore.loadSubkeys(@subkeys)


    # Init component:
    @items = @items()
    @callParent()
    @retentionsStore.each (retention) =>
      @rightPanel.add(@lightCharts[retention.get("name")])

    Ext.defer @showRetention, 1, @, [@defaultRetention]

  items: ->
    [
        @chartContainer = Ext.create "Ext.panel.Panel",
          region: "center"
          header: false
          layout: "fit"
          tbar: [
              "Show:"
            ,
              @retMenu = @createRetentionsMenu()
            , "-",
              xtype: "button"
              text: "Edit Alerts"
              handler: =>
                @showAlertsEditor()
            , "-",
              xtype: "button"
              text: "Select Subkeys"
              disabled: @subkeys.length == 0
              handler: =>
                @showSubkeysSelector()
            , "-",
              xtype: "button"
              text: "Refresh"
              handler: ->
                Muleview.event "refresh"
            , "-",
              text: "Hide Legend"
              enableToggle: true
              pressed: !@showLegend
              toggleHandler: (me, value) =>
                @showLegend = !value
                @renderChart()

          ]
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

  createRetentionsMenu: ->
    clickHandler = (me) =>
      Muleview.event "viewChange", @key, me.retention.get("name")

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
    return unless retName and retName != @currentRetName
    @renderChart(retName)
    @retMenu.selectRetention(retName)

    lightChart.setVisible(lightChart.retention != retName) for own _, lightChart of @lightCharts
    @currentRetName = retName
    Muleview.event "viewChange", @key, @currentRetName

  showAlertsEditor: () ->
    ae = Ext.create "Muleview.view.AlertsEditor",
      alerts: @alerts[@currentRetName]
      key: @key
      retention: @currentRetName
    ae.show()

  showSubkeysSelector: ->
    subkeysSelector = Ext.create "Muleview.view.SubkeysSelector",
      store: @subkeysStore
      callback: @renderChart
      callbackScope: @
    subkeysSelector.show()

  renderChart: (retName = @currentRetName) ->
    @chartContainer.removeAll()
    @selectedSubkeys = @subkeysStore.getSelectedNames()
    @selectedSubkeys.unshift(@key)
    store = @stores[retName]
    unselectedSubkeys = Ext.Array.difference(@subkeys, @selectedSubkeys)
    if unselectedSubkeys.length > 0
      @selectedSubkeys.push(@othersKey)
      store.each (record) =>
        sum = 0
        sum += record.get(otherSubkey) for otherSubkey in unselectedSubkeys
        record.set(@othersKey, sum)
    @chartContainer.add Ext.create "Muleview.view.MuleChart",
      showAreas: true
      keys: @selectedSubkeys
      listeners:
        othersKeyClicked: =>
          @showSubkeysSelector()
      topKey: @key
      alerts: @alerts[retName]
      store: store
      showLegend: @showLegend

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
      keys: @keys
      flex: 1
      topKey: @key
      hidden: true
      retention: retName
      store: @stores[retName]
