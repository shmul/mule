Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"
  requires: [
    "Muleview.store.ChartStore"
  ]

  legend:
    position: "right"
  animate: true

  # Converts the input data hash
  # form: key => [[cout, batch, timestamp], ...]
  # to: [{timestamp: $timestamp, $key1: $key1count, $key2: $key2count ...}, ...]
  convertData: (data) ->
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

  initComponent: ->
    # @data should be a hash of key => keydata,
    # keydata should be: [[count, batch, timestamp], [count, batch, timestamp]...]
    console.log("MuleChart.coffee\\ 34: @data:", @data);

    keys = (key for key, _ of @data)
    console.log("MuleChart.coffee\\ 14: keys:", keys);

    fields = (name: key, type: "integer" for key in keys)
    fields.push(name: "timestamp", type: "integer")
    console.log("MuleChart.coffee\\ 46: fields:", fields);


    @store = Ext.create "Ext.data.ArrayStore"
      fields: fields

    @axes = [
      {
        title: "When?"
        type: "Numeric"
        position: "bottom"
        fields: ["timestamp"]
        label:
          renderer: (timestamp) ->
            Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.labelFormat)
          rotate:
            degrees: 315
        grid: true
      },

      {
        title: 'Count'
        type: 'Numeric'
        position: 'left'
        fields: keys
        minimum: 0
        grid: true
      }
    ]

    areaKeys = Ext.Array.remove(Ext.Array.clone(keys), @topKey)


    @series = [
      {
        type: "area"
        axis: "left"
        xField: "timestamp"
        yField: areaKeys
        highlight: true
      },
      {
        type: "line"
        axis: "left"
        xField: "timestamp"
        yField: [@topKey]
        highlight: true
      }
    ]

    @callParent()
    data = @convertData(@data)
    console.log("MuleChart.coffee\\ 78: data:", data);
    @store.add data
