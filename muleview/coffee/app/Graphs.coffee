Ext.define "Muleview.Graphs",
  singleton: true

  createGraphs: ->
    tabPanel = Ext.getCmp("mainPanel")
    rightPanel = Ext.getCmp("rightPanel")

    tabPanel.removeAll();
    rightPanel.removeAll()

    Muleview.Mule.getKeyData Muleview.currentKey, (data) =>
      # Data is in the form "key => retention => data", so we need to reverse it to retention-based first:
      retentions = {}
      progressCount = 0
      keys = []
      for key, rets of data
        keys.push(key)
        for retention, retentionData of rets
          retentions[retention] ||= {}
          retentions[retention][key] = retentionData
          progressCount += retentionData.length

      # Now, create a graph for each retention:
      for ret, retData of retentions
        do (ret, retData) ->
          mainGraphPanel = Ext.create "Ext.panel.Panel",
            title: ret
            layout: "fit"
            items: [
              Ext.create "Muleview.view.MuleChart",
                showAreas: true
                data: retData
                keys: keys
                topKey: Muleview.currentKey
            ]

          lightGraph = Ext.create "Muleview.view.MuleLightChart",
            keys: keys
            topKey: Muleview.currentKey
            data: retData
            retention: ret
            listeners:
              mouseenter: ->
                tabPanel.setActiveTab(mainGraphPanel)

          tabPanel.add mainGraphPanel
          rightPanel.add lightGraph

      tabPanel.setActiveTab(0)

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
