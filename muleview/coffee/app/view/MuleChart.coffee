Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"

  showAreas: true
  highlight: true

  legend:
    position: "right"
  animate: true
  theme: "Category2"

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

  tipsRenderer: (storeItem, item) ->
    me = item.series.chart
    key = item.storeField or me.topKey
    value = storeItem.get(key)
    total = storeItem.get(me.topKey)
    percent = 100 * (value / total)
    percentText = Ext.util.Format.number(percent, "0.00")
    timestamp = me.timeFormatter(storeItem.get('timestamp'))
    @update
      key: key.substring(key.lastIndexOf(".") + 1)
      timestamp: timestamp
      total: Ext.util.Format.number(total, ",")
      value: Ext.util.Format.number(value, ",")
      percent: percentText

  timeFormatter: (timestamp) ->
    Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.labelFormat)

  initComponent: ->
    me = @
    @timeLabel.renderer = @timeFormatter

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
      highlight: true
      tips:
        tpl: "{key} {value} ({timestamp})"
        renderer: @tipsRenderer

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
          trackMouse: false
          anchor: "left"
          tpl: "<b>{key}, {timestamp} </b></br><hr>{value} / {total} (<b>{percent}%</b>)"
          renderer: @tipsRenderer


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
              trackMouse: false
              anchor: "bottom"
              title: "Alert"
              html: "<i><b>#{alert.label}</b> (#{Ext.util.Format.number(alert.value, ",")})</i>"
    @callParent()

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)