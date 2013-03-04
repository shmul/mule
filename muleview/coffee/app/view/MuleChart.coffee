Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"

  showAreas: true
  highlight: true

  legend:
    position: "bottom"
  animate: true

  timeLabel:
    renderer: (timestamp) ->
      Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.labelFormat)
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

    # Alerts:
    if @alerts
      for alert in @alerts
        do (alert) =>
          return if alert.time
          alertSeries =
            type: "line"
            showMarkers: true
            markerConfig:
              radius: 0
              "stroke-width": 0
              width: 0
              opacity: 0
            axis: "left"
            xField: "timestamp"
            yField: [alert.name]
            highlight: true
            tips:
              trackMouse: true
              html: "#{alert.label} = #{alert.value}"
              title: "Alert"
          if alert.color
            alertSeries.style =
              stroke: alert.color
          @series.push alertSeries


    # Areas:
    if @showAreas
      @series.push
        type: "area"
        axis: "left"
        xField: "timestamp"
        yField: areaKeys
        highlight: @highlight

    # Top key line:
    @series.push
      type: "line"
      axis: "left"
      xField: "timestamp"
      yField: [@topKey]
      highlight: @highlight



    @callParent()
