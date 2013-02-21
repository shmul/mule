Ext.define "Muleview.Graphs",
  singleton: true

  createGraphs: ->
    @tabPanel = Ext.getCmp("mainPanel")
    @rightPanel = Ext.getCmp("rightPanel")

    @tabPanel.removeAll();
    @rightPanel.removeAll()

    # Obtain data:
    Muleview.Mule.getKeyData Muleview.currentKey, (data) =>
      # Convert data:
      retentions = @convertData(data)

      # Count data:
      recordsCount = 0
      for ret, retData of retentions
        recordsCount += retData.length

      processedRecords = 0
      pbar = Ext.MessageBox.progress("Progress")
      inc = ->
        processedRecords += 1
        pbar.updateProgress(processedRecords / recordsCount)
        pbar.close() if processedRecords >= recordsCount

      # Create two graphs, main and light, for each retention:
      for ret, retData of retentions
        Ext.defer @createRetentionGraphs, 1, @, [ret, retData, inc]

  createRetentionGraphs: (ret, data, inc) ->
    console.log("Graphs.coffee\\ 22: ret, data:", ret, data);

    # Extract retention keys from data:
    keys = {}
    for record in data
      for key, value of record
        keys[key] = true

    keys = Ext.Object.getKeys(keys)
    console.log("Graphs.coffee\\ 24: keys:", keys);
    return unless keys.length > 0

    fields = (name: key, type: "integer" for key in keys)
    Ext.Array.remove(keys, "timestamp")

    store = Ext.create "Ext.data.ArrayStore"
      fields: fields

    mainGraphPanel = Ext.create "Ext.panel.Panel",
      title: ret
      layout: "fit"
      items: [
        Ext.create "Muleview.view.MuleChart",
          showAreas: true
          keys: keys
          store: store
          topKey: Muleview.currentKey
      ]

    lightGraph = Ext.create "Muleview.view.MuleLightChart",
      keys: keys
      topKey: Muleview.currentKey
      retention: ret
      store: store
      listeners:
        mouseenter: =>
          @tabPanel.setActiveTab(mainGraphPanel)


    for record in data
      do (record) ->
        Ext.defer ->
          store.add(record)
          inc()
        , 1

    Ext.defer =>
      @tabPanel.add mainGraphPanel
      @rightPanel.add lightGraph
    , 1

  # We need to convert the data
  # Form "retention => key => data"
  # To: retention => [ {timestamp: XXX, key1: XXX, key2: XXX ...}, ...]
  convertData: (data) ->
    ans = {}
    for retention, retentionData of data
      ans[retention] = @convertRetentionData(retentionData)
    ans

  # Converts the input data hash
  # form: key => [[cout, batch, timestamp], ...]
  # to: [{timestamp: $timestamp, $key1: $key1count, $key2: $key2count ...}, ...]
  convertRetentionData: (data) ->
    timestamps = {}
    for own key, keyData of data
      for [count, _, timestamp] in keyData
        timestamps[timestamp] ||= {}
        timestamps[timestamp][key] = count
    ans = []
    for timestamp, counts of timestamps
      record = {
        timestamp: timestamp
      }

      for key, keyCount of counts
        record[key] = keyCount
      ans.push record
    ans
