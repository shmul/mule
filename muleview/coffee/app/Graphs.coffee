Ext.define "Muleview.Graphs",
  singleton: true

  createGraphs: (newKey, callback)->
    @mainPanel = Ext.getCmp("mainPanel")
    @rightPanel = Ext.getCmp("rightPanel")

    # Reset and initiate:
    @retentions = {}
    @mainPanel.removeAll();
    @mainPanel.setLoading(true)
    @rightPanel.removeAll()
    @rightPanel.setLoading(true)

    # Obtain data:
    Muleview.Mule.getKeyData newKey, (data, alerts) =>
      for own retention, retentionData of data
        @retentions[retention] = @createRetentionGraphs(retention, retentionData, alerts)

      @rightPanel.add(ret.lightGraph for _, ret of @retentions)
      @mainPanel.add(ret.graph for _, ret of @retentions )
      @mainPanel.setLoading(false)
      @rightPanel.setLoading(false)
      Muleview.event "graphsCreated"
      Muleview.currentKey = newKey
      callback?()

  # Receives a retention name and the graph's alerts in Mule's raw format
  # Returns an array of the alerts with their metadata as predefined in Muleview.Settings.alerts
    # Input: {"myGreatKey.subkey;1m:1h": [ 0, 10, 1000, 5000, 60, 60], ...}
    # Output: [
      # {
        # name: "critical_low"
        # label: "Critical Low"
        # value: 0
      # }, {
        # name: "warning_low"
        # label: "Warning Low"
        # value: 10
   #  (...)
  getAlerts: (topKey, retention, alertsHash) ->
    graphName = topKey + ";" + retention
    ans = null
    raw = alertsHash?[graphName]
    if raw
      ans = []
      for meta, i in Muleview.Settings.alerts
        ans[i] = Ext.apply({value: raw[i]}, meta)
    ans

  createRetentionGraphs: (retName, retRawData, alertsHash) ->
    keys = Ext.Object.getKeys(retRawData)
    topKey = @findTopKey(keys)
    alerts = @getAlerts(topKey, retName, alertsHash)
    store = @createStore(retRawData, keys, alerts)

    mainGraphPanel = Ext.create "Muleview.view.MuleChartPanel",
      title: @parseTitle(retName)
      retention: retName
      keys: keys
      topKey: topKey
      alerts: alerts
      store: store

    lightGraph = Ext.create "Muleview.view.MuleLightChart",
      title: @parseTitle(retName)
      keys: keys
      topKey: topKey
      hidden: true
      retention: retName
      store: store

    return {
      graph: mainGraphPanel
      lightGraph: lightGraph
      alerts: alerts
    }

  # Find the topmost key in the given keys array
  # The top key is the shortest of all (and should, btw, be the prefix of all, too)
  findTopKey: (keys) ->
    topKey = keys[0]
    for key in keys
      topKey = key if key.length < topKey.length
    topKey



  # Creates a flat store from a hash of {
  #   key1 => [[cout, batch, timestamp], ...],
  #   key2 => [[cout, batch, timestamp], ...]
  # }
  createStore: (retentionData, keys, alerts) ->
    # Initialize store:
    fields = (name: key, type: "integer" for key in keys)
    fields.push(name: "timestamp", type: "integer")
    fields.push {name: alert.name, type: "integer"} for alert in alerts if alerts

    store = Ext.create "Ext.data.ArrayStore",
      fields: fields
      sorters: [
          property: "timestamp"
      ]

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

  parseTitle: (ret) ->
    split = ret.split(":")
    last = split[1]
    [_all, count, letter] = match = last.match /(\d+)([mhsdy])/
    units = {
      "h": "hours"
      "m": "minutes"
      "d": "days"
    }[letter]
    "Last #{count} #{units}"