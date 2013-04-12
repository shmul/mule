Ext.define "Muleview.view.ChartsView",
  extend: "Ext.panel.Panel"
  alias: "widget.chartsview"
  requires: [
    "Ext.form.field.ComboBox"
    "Muleview.model.Retention"
    "Muleview.view.MuleChartPanel"
    "Muleview.view.MuleLightChart"
    "Ext.data.ArrayStore"
  ]
  header: false
  layout: "border"
  othersKey: Muleview.Settings.othersSubkeyName

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
    @keys.push(@othersKey)

    # Create all stores and light charts:
    @stores = {}
    @lightCharts = {}
    @retentionsStore.each (retention) =>
      name = retention.get("name")
      @stores[name] = @createStore(name)
      @lightCharts[name] = @createLightChart(retention)

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
              @retCombo = Ext.create "Ext.form.field.ComboBox",
                fieldLabel: "Show"
                forceSelection: true
                # editable: false
                labelWidth: 40
                displayField: "title"
                valueField: "name"
                store: @retentionsStore
                width: "auto"
                listeners:
                  scope: @
                  select: (me, retentions)->
                    retention = retentions[0]
                    return unless retention
                    Muleview.event "viewChange", @key, retention.get("name")
            ,
              xtype: "button"
              text: "Edit Alerts"
            ,
              xtype: "button"
              text: "Select Subkeys"
            ,
              xtype: "button"
              text: "Refresh"
              handler: ->
                Muleview.event "refresh"
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

  selectSubkeys: ->
    ans = Ext.clone(@keys)



    Ext.Array.include(ans, @othersKey)
    ans

  renderChart: ->
    console.log('ChartsView.coffee\\ 97: @keys:', @keys);
    console.log('ChartsView.coffee\\ 98: @subkeys:', @subkeys);
    console.log('ChartsView.coffee\\ 99: @store:', @store);

  preprocessData: (data) ->
    data

  showRetention: (retName) ->
    return unless retName and retName != @currentRetName
    @renderChart(retName)

    @retCombo.select retName
    lightChart.setVisible(lightChart.retention != retName) for own _, lightChart of @lightCharts
    @currentRetName = retName
    Muleview.event "viewChange", @key, @currentRetName


  selectSubkeys: ->
    @subkeys[0...Muleview.Settings.defaultSubkeys]

  renderChart: (retName) ->
    @chartContainer.removeAll()
    selectedSubkeys = @customSelectedSubkeys || @selectSubkeys()
    selectedSubkeys.unshift(@key)
    store = @stores[retName]
    unselectedSubkeys = Ext.Array.difference(@subkeys, selectedSubkeys)
    if unselectedSubkeys.length > 0
      selectedSubkeys.push(@othersKey)
      store.each (record) =>
        sum = 0
        sum += record.get(otherSubkey) for otherSubkey in unselectedSubkeys
        record.set(@othersKey, sum)

    @chartContainer.add Ext.create "Muleview.view.MuleChart",
      showAreas: true
      keys: selectedSubkeys
      topKey: @key
      alerts: @alerts
      store: store

  # Creates a flat store from a hash of {
  #   key1 => [[count, batch, timestamp], ...],
  #   key2 => [[count, batch, timestamp], ...]
  # }
  createStore: (retName) ->
    # Create initial store:
    store = @createEmptyStore()
    # Convert data to timestamps-based hash:
    timestamps = {}
    for own key, keyData of @data[retName]
      for [count, _, timestamp] in keyData
        unless timestamps[timestamp]
          timestamps[timestamp] = {
            timestamp: timestamp
          }
          timestamps[timestamp][alert.name] = alert.value for alert in @alerts if @alerts
        timestamps[timestamp][key] = count

    # Add the data:
    store.add(Ext.Object.getValues(timestamps))
    store

  createEmptyStore: ->
    # Initialize store:
    fields = (name: key, type: "integer" for key in @keys)
    fields.push(name: "timestamp", type: "integer")
    fields.push {name: alert.name, type: "integer"} for alert in @alerts if @alerts

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
