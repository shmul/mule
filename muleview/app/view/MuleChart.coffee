Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"
  requires: [
    "Muleview.view.Theme"
    "Ext.chart.series.Line"
    "Ext.chart.series.Area"
    "Ext.chart.axis.Numeric"
  ]

  statics:
    lastXY: [0,0] # Used to workaround an Extjs bug causing errors when showing tooltips of a chart created below the mouse cursor

  shadow: false

  legend:
    position: "right"
  animate: false
  theme: "Muleview"

  timeLabel:
    rotate:
      degrees: -45

  tipsRenderer: (storeItem, item) ->
    me = item.series.chart
    key = item.storeField or item.series.title
    value = storeItem.get(key)
    total = storeItem.get(me.topKeys[0]) # We seriously hope there's only one topKey
    percent = 100 * (value / total)
    percentText = Ext.util.Format.number(percent, "0.00")
    timestamp = (new Date(storeItem.get('timestamp') * 1000)).toUTCString()
    @update
      key: key.substring(key.lastIndexOf(".") + 1)
      timestamp: timestamp
      total: Ext.util.Format.number(total, ",")
      value: Ext.util.Format.number(value, ",")
      percent: percentText

  createTimeFormatter: () ->
    lastDate = null
    return (timestamp) ->
      # convert the timestamp to UTC date and return a formatted string according to the formatting specified in Muleview's settings
      rawDate = new Date(timestamp * 1000)
      day = rawDate.getUTCDay()
      utcDate = Muleview.toUTCDate(rawDate)
      ans = Ext.Date.format(utcDate, Muleview.Settings.labelTimeFormat)
      if (lastDate != day)
        lastDate = day
        ans = Ext.Date.format(utcDate, Muleview.Settings.labelDateFormat) + "\n" + ans
      ans

  initComponent: ->
    @timeLabel.renderer = @createTimeFormatter()

    @axes = [
      {
        type: "Numeric"
        position: "bottom"
        fields: ["timestamp"]
        label: @timeLabel
        adjustEnd: false
        majorTickSteps: 20
        grid: false
        dashSize: 4
      },

      {
        type: 'Numeric'
        position: 'left'
        majorTickSteps: 20
        fields: @keys
        minimum: 0
        grid: true
      }
    ]

    @series = []

    # Top keys:
    for topKey in @topKeys
      @series.push
        type: "line"
        axis: "left"
        title: @keyLegendName(topKey)
        xField: "timestamp"
        yField: [topKey]
        highlight: false
        listeners:
          itemmouseover: (item) ->
            Muleview.event "chartItemMouseOver", item
        style:
          "stroke-width": (if Ext.isEmpty(@subKeys) then 2.5 else 0)
        tips:
          trackMouse: false
          tpl: "{key} {value} ({timestamp})"
          renderer: @tipsRenderer
          targetXY: @self.lastXY

    # Subkeys:
    if @subKeys
      @series.push
        type: "area"
        axis: "left"
        xField: "timestamp"
        yField: @subKeys
        title: @keyLegendName(key) for key in @subKeys
        highlight: true
        listeners:
          itemmouseover: (item) ->
            Muleview.event "chartItemMouseOver", item
          itemclick: (item) =>
            @areaClickHandler item.storeField
        tips:
          trackMouse: false
          anchor: "left"
          tpl: "<b>{key}</b> <hr /> <b>Time: </b>{timestamp}<br><b> Value: </b> {value} <br /><b>Percent:</b>{percent}%"
          renderer: @tipsRenderer
          targetXY: @self.lastXY

    # Alerts:
    if @alerts
      for alert in @alerts
        @series.push
          type: "line"
          title: "'#{alert.label}' alert"
          showMarkers: true
          style:
            stroke: alert.color
            opacity: 0.3
            "stroke-width": 3
            "stroke-dasharray": 10
          markerConfig:
            type: "arrow"
            radius: 0.1
            opacity: 0
          axis: "left"
          xField: "timestamp"
          yField: [alert.name]
          highlight: false
          tips:
            trackMouse: false
            anchor: "bottom"
            title: "Alert"
            html: "<i><b>#{alert.label}</b> (#{Ext.util.Format.number(alert.value, ",")})</i>"
            targetXY: @self.lastXY

    # Remove default legend if necessary:
    @legend = false unless @showLegend
    @callParent()
    @on
      mousemove: (e, opts) =>
        @self.lastXY = e.getXY()
      scope: @

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)

  areaClickHandler: (key) ->
    if key == Muleview.Settings.othersSubkeyName
      @fireEvent "othersKeyClicked"
    else
      Muleview.event "viewChange", key, null
