Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"

  showAreas: true
  highlight: true

  legend:
    position: "right"
  animate: true

  timeLabel:
    rotate:
      degrees: 315

  # Find the topmost key in the given keys array
  # The top key is the shortest of all (and should, btw, be the prefix of all, too)
  findTopKey: (keys) ->
    topKey = keys[0]
    for key in keys
      topKey = key if key.length < topKey.length
    topKey

  initComponent: ->
    me = @
    timeFormatter = (timestamp) ->
      Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.labelFormat)
    @timeLabel.renderer = timeFormatter

    # @data should be a hash of key => keydata,
    # keydata should be: [[count, batch, timestamp], [count, batch, timestamp]...]

    keys = @keys
    @topKey = @findTopKey(keys)

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

    # Top key line:
    @series.push
      type: "line"
      axis: "left"
      title: @keyLegendName @topKey
      xField: "timestamp"
      yField: [@topKey]
      highlight: @highlight

    # Areas:
    if @showAreas
      @series.push
        type: "area"
        axis: "left"
        xField: "timestamp"
        yField: areaKeys
        title: @keyLegendName(key) for key in areaKeys
        highlight: @highlight
        tips:
          trackMouse: true
          tpl: "<b>{key}, {timestamp} </b></br><hr>{value} / {total} (<b>{percent}%</b>)"
          renderer: (storeItem, item) ->
            console.log('MuleChart.coffee\\ 79: item:', item);
            console.log('MuleChart.coffee\\ 80: storeItem:', storeItem);
            key = item.storeField
            value = storeItem.get(item.storeField)
            total = storeItem.get(me.topKey)
            percent = 100 * (value / total)
            percentText = Ext.util.Format.number(percent, "0.00")
            timestamp = timeFormatter(storeItem.get('timestamp'))
            # @setTitle "#{key} #{timestamp}"
            @update
              key: key.substring(key.lastIndexOf(".") + 1)
              timestamp: timestamp
              total: Ext.util.Format.number(total, ",")
              value: Ext.util.Format.number(value, ",")
              percent: percentText

    # Alerts:
    if @alerts
      for alert in @alerts
        do (alert) =>
          unless alert.time then @series.push
            type: "line"
            title: "'#{alert.label}' alert"
            showMarkers: true
            style:
              stroke: alert.color
            markerConfig:
              type: "arrow"
              radius: 0.1
              opacity: 0
            axis: "left"
            xField: "timestamp"
            yField: [alert.name]
            highlight: true
            tips:
              trackMouse: true
              html: "#{alert.label} = #{alert.value}"
              title: "Alert"
    @callParent()

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)