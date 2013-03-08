Ext.define "Muleview.Graphs",
  singleton: true

  createGraphs: ->
    Muleview.event "createGraphStart"
    @mainPanel = Ext.getCmp("mainPanel")
    @rightPanel = Ext.getCmp("rightPanel")
    previousSelectedRetention = Muleview.currentRetention

    # Reset and initiate display progress start:
    @retentions = {}
    @mainPanel.removeAll();
    @mainPanel.setLoading(true)
    @rightPanel.removeAll()
    @rightPanel.setLoading(true)

    # Obtain data:
    Muleview.Mule.getKeyData Muleview.currentKey, (data, alerts) =>
      firstTab = null
      for own retention, retentionData of data
        @retentions[retention] = @createRetentionGraphs(retention, retentionData, alerts)
        firstTab ||= @retentions[retention].graph

      @rightPanel.add(ret.lightGraph for _, ret of @retentions)
      @mainPanel.add(ret.graph for _, ret of @retentions )
      @mainPanel.setActiveTab(@retentions[previousSelectedRetention]?.graph or firstTab)
      @mainPanel.setLoading(false)
      @rightPanel.setLoading(false)
      Muleview.event "createGraphEnd"

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
  getAlerts: (retention, alertsHash) ->
    graphName = Muleview.currentKey + ";" + retention
    ans = null
    raw = alertsHash?[graphName]
    if raw
      ans = []
      for meta, i in Muleview.Settings.alerts
        ans[i] = Ext.apply({value: raw[i]}, meta)
    ans

  createRetentionGraphs: (retName, retRawData, alertsHash) ->
    keys = Ext.Object.getKeys(retRawData)
    alerts = @getAlerts(retName, alertsHash)
    store = @createStore(retRawData, keys, alerts)

    mainGraphPanel = Ext.create "Muleview.view.MuleChartPanel",
      title: @parseTitle(retName)
      retention: retName
      keys: keys
      alerts: alerts
      store: store

    lightGraph = Ext.create "Muleview.view.MuleLightChart",
      retention: retName
      title: @parseTitle(retName)
      keys: keys
      hidden: true
      retention: retName
      store: store

    return {
      graph: mainGraphPanel
      lightGraph: lightGraph
      alerts: alerts
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