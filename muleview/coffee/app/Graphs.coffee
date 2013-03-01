Ext.define "Muleview.Graphs",
  singleton: true

  createGraphs: ->
    @mainPanel = Ext.getCmp("mainPanel")
    @rightPanel = Ext.getCmp("rightPanel")

    # Reset and initiate display progress start:
    @retentions = {}
    @mainPanel.removeAll();
    @mainPanel.setLoading(true)
    @rightPanel.removeAll()
    @rightPanel.setLoading(true)

    # Obtain data:
    Muleview.Mule.getKeyData Muleview.currentKey, (data) =>
      firstTab = null
      for own retention, retentionData of data
        @retentions[retention] = @createRetentionGraphs(retention, retentionData)
        firstTab ||= @retentions[retention].graph

      @rightPanel.add(ret.lightGraph for _, ret of @retentions)
      @mainPanel.add(ret.graph for _, ret of @retentions )
      @mainPanel.setActiveTab(firstTab)
      @mainPanel.setLoading(false)
      @rightPanel.setLoading(false)

  getAlerts: (graphName) ->
    ans = null
    raw = Muleview.alerts[graphName]
    if raw
      ans = []
      for meta, i in Muleview.Settings.alerts
        ans[i] = Ext.apply({value: raw[i]}, meta)
    ans

  createRetentionGraphs: (retName, retRawData) ->
    keys = Ext.Object.getKeys(retRawData)
    alerts = @getAlerts(Muleview.currentKey + ";" + retName) # TODO: get it in some other way

    store = @createStore(retRawData, keys, alerts)
    mainGraphPanel = Ext.create "Ext.panel.Panel",
      title: retName
      retention: retName
      layout: "fit"
      items: [
        Ext.create "Muleview.view.MuleChart",
          showAreas: true
          keys: keys
          alerts: alerts
          store: store
      ]

    lightGraph = Ext.create "Muleview.view.MuleLightChart",
      retention: retName
      keys: keys
      hidden: true
      retention: retName
      store: store

    return {
      graph: mainGraphPanel
      lightGraph: lightGraph
    }

  # Creates a flat store from a hash of {
  #   key1 => [[cout, batch, timestamp], ...],
  #   key2 => [[cout, batch, timestamp], ...]
  # }
  createStore: (retentionData, keys, alerts) ->
    # Initialize store:
    fields = (name: key, type: "integer" for key in keys)
    fields.push(name: "timestamp", type: "integer")
    fields.push {name: alert.name, type: "integer"} for alert in alerts if alerts

    store = Ext.create "Ext.data.ArrayStore"
      fields: fields

    # Convert data to timestamps-based hash:
    timestamps = {}
    for own key, keyData of retentionData
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