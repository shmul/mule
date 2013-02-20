Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"
  requires: [
    "Muleview.store.ChartStore"
  ]

  showAreas: true

  legend:
    position: "bottom"
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

  timeLabel:
    renderer: (timestamp) ->
      Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.labelFormat)
    rotate:
      degrees: 315

  initComponent: ->
    # @data should be a hash of key => keydata,
    # keydata should be: [[count, batch, timestamp], [count, batch, timestamp]...]

    keys = (key for key, _ of @data)

    fields = (name: key, type: "integer" for key in keys)
    fields.push(name: "timestamp", type: "integer")


    @store = Ext.create "Ext.data.ArrayStore"
      fields: fields

    @axes = [
      {
        type: "Numeric"
        position: "bottom"
        fields: ["timestamp"]
        label: @timeLabel
        grid: true
      },

      {
        type: 'Numeric'
        position: 'left'
        fields: keys
        minimum: 0
        grid: true
      }
    ]

    areaKeys = Ext.Array.remove(Ext.Array.clone(keys), @topKey)


    @series = []
    if @showAreas
      @series.push {
        type: "area"
        axis: "left"
        xField: "timestamp"
        yField: areaKeys
        highlight: true
      }
    @series.push {
        type: "line"
        axis: "left"
        xField: "timestamp"
        yField: [@topKey]
        highlight: true
      }

    @callParent()
    data = @convertData(@data)
    @store.add data
