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
      for own retention, retentionData of data
        @retentions[retention] = @createRetentionGraphs(retention, retentionData)
        @mainPanel.add(@retentions[retention].graph)

      @mainPanel.setLoading(false)
      @rightPanel.setLoading(false)




  createRetentionGraphs: (retName, retRawData) ->
    keys = Ext.Object.getKeys(retRawData)
    store = @createStore(retRawData, keys)
    console.log('Graphs.coffee\\ 30: store:', store);
    mainGraphPanel = Ext.create "Ext.panel.Panel",
      title: retName
      layout: "fit"
      items: [
        Ext.create "Muleview.view.MuleChart",
          showAreas: true
          keys: keys
          store: store
      ]

    lightGraph = Ext.create "Muleview.view.MuleLightChart",
      keys: keys
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
  createStore: (retentionData, keys) ->
    # Initialize store:
    fields = (name: key, type: "integer" for key in keys)
    fields.push(name: "timestamp", type: "integer")

    store = Ext.create "Ext.data.ArrayStore"
      fields: fields

    # Convert data to timestamps-based hash:
    timestamps = {}
    for own key, keyData of retentionData
      for [count, _, timestamp] in keyData
        timestamps[timestamp] ||= {
          timestamp: timestamp
        }
        timestamps[timestamp][key] = count

    # Add the data:
    store.add(Ext.Object.getValues(timestamps))
    store