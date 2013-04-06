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

  initComponent: ->
    # Init retentions (these are just the names, for the combo box)
    retentions = (new Muleview.model.Retention(retName) for own retName of @data)
    @retentionsStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Retention"
      sorters: ["sortValue"]
      data: retentions


    @defaultRetention ||= @retentionsStore.getAt(0).get("name")
    @keys = Ext.Object.getKeys(@data[@defaultRetention])
    @store = @createEmptyStore()


    # Init component:
    @items = @items()
    @callParent()
    @showRetention @defaultRetention

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
        ]
        items: [
          @chart = Ext.create "Muleview.view.MuleChart",
            showAreas: true
            keys: @keys
            topKey: @key
            alerts: @alerts
            store: @store
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
        defaults:
          flex: 1
    ]

  showRetention: (retName) ->
    console.log('ChartsView.coffee\\ 88: retName:', retName);
    return unless retName and retName != @currentRetName
    console.log("ChartsView.coffee\\ 90: <HERE>");
    @store.removeAll()
    @store.loadData(@getStore(retName).data.items)
    console.log('ChartsView.coffee\\ 91: @retCombo.getValue():', @retCombo.getValue());
    @retCombo.select retName
    console.log('ChartsView.coffee\\ 93: @retCombo.getValue():', @retCombo.getValue());
    @currentRetName = retName

  # Creates a flat store from a hash of {
  #   key1 => [[count, batch, timestamp], ...],
  #   key2 => [[count, batch, timestamp], ...]
  # }
  createStore: (retentionData) ->
    # Create initial store:
    store = @createEmptyStore()
    # Convert data to timestamps-based hash:
    timestamps = {}
    for own key, keyData of retentionData
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

  # Lazy-create each retention's store
  getStore: (retName) ->
    @stores ||= {}
    unless @stores[retName]
      @stores[retName] = @createStore(@data[retName])
    ans = @stores[retName]
    ans

  # createBigChart: (retName) ->
  #   keys = key for own key of @data[retName]
  #   Ext.create "Muleview.view.MuleChartPanel",
  #     title: @retentionsStore.getById(retName).get("title")
  #     retention: retName
  #     keys: keys
  #     topKey: @key
  #     alerts: @alerts
  #     store: @getStore(retName)
