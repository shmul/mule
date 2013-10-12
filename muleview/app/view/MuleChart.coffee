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

  createTips: (opts) ->
    tplArr = ["
      <div class=\"mule-tt-head\">
        {key}
      </div>
      <hr />
      <table>"
    ]

    addData = (td1, td2) ->
      tplArr.push("
        <tr>
          <td><b>#{td1}:</b></td>
          <td>{#{td2}}</td>
        </tr>")

    addData("Value", "value")
    addData("Percent", "percent") if opts.showPercent
    tplArr.push("<tr><td colspan=2><hr /></td></tr>")
    addData("Day", "day")
    addData("Date", "date")
    addData("Time", "time")

    tplArr.push("</table>")

    return {
      anchor: opts.anchor
      anchorOffset: 135
      trackMouse: false
      targetXY: @self.lastXY
      tpl: tplArr.join("")
      dismissDelay: 0
      renderer: @tipsRenderer
    }
  tipsRenderer: (storeItem, item) ->
    # Main:
    chart = item.series.chart
    key = item.storeField or item.series.yField[0]

    # Values:
    value = storeItem.get(key)
    total = storeItem.get(chart.topKeys[0]) # 'Total' field is only used by subkeys => we seriously hope there's only one topKey

    # Percent:
    percent = 100 * (value / total)

    # Time:
    utcOffset = new Date().getTimezoneOffset() * 60
    dateObj = new Date((storeItem.get('timestamp') + utcOffset) * 1000)

    # Update html according to tpl with formatted values:
    @update
      key: key.substring(key.lastIndexOf(".") + 1)
      date:    Ext.Date.format(dateObj, "Y-m-d")
      day:     Ext.Date.format(dateObj, "l")
      time:    Ext.Date.format(dateObj, "H:i:s")
      total:   Ext.util.Format.number(total, ",")
      value:   Ext.util.Format.number(value, ",")
      percent: Ext.util.Format.number(percent, "0.00") + "%"

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
        tips: @createTips
          anchor: "botom"


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
        tips: @createTips
          anchor: "top"
          showPercent: true

    # Alerts:
    if @alerts
      for alert in @alerts
        @series.push
          type: "line"
          title: "'#{alert.label}' (avg.)"
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
            anchor: alert.name.match("critical") and "right" or "left"
            title: "Alert Average"
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
