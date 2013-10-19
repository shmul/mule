Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.container.Container"
  requires: [
    "Muleview.view.Theme"
  ]

  layout: "fit"
  slider: true
  padding: 7
  mainGraph: true

  initComponent: ->
    @series = @createSeries()

    @on
      boxready: @renderChart
      resize: @renderChart
      scope: @

    @callParent()

  createGraphContainer: ->
    @removeAll()

    # Create new IDs for divs:
    @divs =
      chart: Ext.id()
      legend: Ext.id()
      slider: Ext.id()
      fixedTip: Ext.id()

    # Prepare HTML content with new IDs:
    cmpHtml = '
        <div style="display: block">
          <div class="rickshaw-chart" id="' + @divs.chart + '"> </div>
          <div class="rickshaw-legend" id="' + @divs.legend + '"> </div>
        </div>
        <div class="rickshaw-slider" id="' + @divs.slider + '" > </div>
      '
    cmpHtml += '<div id="rickshaw-fixed-tooltip"> </div>' if @mainGraph

    # Create main element:
    @add @graphContainer = Ext.create "Ext.Component",
      autoEl: "div"
      html: cmpHtml

    # Replace IDs with actual DOM nodes' references:
    for key, id of @divs
      @divs[key] = document.querySelector("#" + id)

  renderChart: () ->

    # Remove old components and create container:
    @createGraphContainer()

    # Main Graph
    @graph = new Rickshaw.Graph
      element: @divs.chart
      interpolation: "step"
      width: @graphContainer.getWidth()
      height: @graphContainer.getHeight() - 30
      renderer: "multi"
      series: @series
    window.g = @graph

    # X Axis:
    new Rickshaw.Graph.Axis.Time
      graph: @graph
      pixelsPerTick: 100

    # Y Axis:
    new Rickshaw.Graph.Axis.Y
      graph: @graph
      tickFormat: Ext.util.Format.numberRenderer(",0")

    @createLegend()
    @graph.render()
    @createTooltips()
    @createSlider()

  createLegend: ->
    return unless @showLegend
    legend = new Rickshaw.Graph.Legend
      element: @divs.legend
      graph: @graph

    new Rickshaw.Graph.Behavior.Series.Toggle
      graph: @graph
      legend: legend

    new Rickshaw.Graph.Behavior.Series.Highlight
      graph: @graph
      legend: legend
      disabledColor: -> "rgba(0, 0, 0, 0.2)"


  createSlider: ->
    return unless @slider
    new Rickshaw.Graph.RangeSlider
      graph: @graph
      element: @divs.slider

  createTooltips: ->
    tpl = new Ext.XTemplate('
    <table style="width: 100%">
      <tr>
        <td style="text-align: left">
          <span class="rickshaw-fixedtip-colorbox" style="background-color: {color}"></span>
          <b>{key}</b> - {valueText}
        </td>
        <td style="text-align: right">
          {timestamp}
        </td>
      </tr>
    </table>
    ')

    muleChart = @

    FixedTooltip =  Rickshaw.Class.create Rickshaw.Graph.HoverDetail,

      render: ($super, args) =>
        $super(args)
        @element ||= document.querySelector("#rickshaw-fixed-tooltip")
        point = (args.points.filter (p) -> p.active).shift()

        percent =  point.value.percent
        percentText = Ext.util.Format.number(percent, "0.00")

        value = point.value.y
        valueText = Ext.util.Format.number(value, ",0")
        valueText += " (#{percentText}%)" if point.series.type == "subkey"

        @element.innerHTML = tpl.apply
          key: point.name
          valueText: valueText
          color: point.series.color
          timestamp: point.formattedXValue
        @show()

      SKIP_formatter: (series, x, y) =>
        tplArr = ["
          <div class=\"mule-tt-head\" style=\"display: inline-block\">
            #{series.name}
          </div>
          <span class=\"mule-tt-colorbox\" style=\"background-color: #{series.color} \"></span>
          <hr />
          <table>"
        ]

        addData = (td1, td2) ->
          tplArr.push("
            <tr>
              <td><b>#{td1}:</b></td>
              <td>#{td2}</td>
            </tr>")

        # Time:
        utcOffset = new Date().getTimezoneOffset() * 60
        dateObj = new Date((x + utcOffset) * 1000)
        date = Ext.Date.format(dateObj, "Y-m-d")
        day = Ext.Date.format(dateObj, "l")
        time = Ext.Date.format(dateObj, "H:i:s")

        addData("Value", Ext.util.Format.number(y, ",0"))
        tplArr.push("<tr><td colspan=2><hr /></td></tr>")
        addData("Day", day)
        addData("Date", date)
        addData("Time", time)

        tplArr.push("</table>")
        tplArr.join("")

    hover = new FixedTooltip
      graph: @graph


  createSeriesData: (series) ->
    ans = []
    @store.each (record) =>
      total = record.get(@topKeys[0])
      value = record.get(series)
      percent = 100 * value / total
      ans.push
        x: record.get("timestamp")
        y: value
        percent: percent
    ans

  createSeries: ->
    palette = new Rickshaw.Color.Palette
      scheme: new Muleview.view.Theme().colors

    alertsStart = @store.min("timestamp")
    alertsEnd = @store.max("timestamp")

    series = []

    for topKey in @topKeys
      series.push
        name: @keyLegendName(topKey)
        color: palette.color()
        data: @createSeriesData(topKey)
        type: "topkey"
        renderer: "line"

    for subKey in (@subKeys || [])
      series.push
        name: @keyLegendName(subKey)
        color: palette.color()
        data: @createSeriesData(subKey)
        type: "subkey"
        stroke: 0
        renderer: "stack"

    for alert in (@alerts || [])
      series.push
        name: alert.label
        color: alert.color
        renderer: "line"
        isAlert: true
        data: @createSeriesData(alert.name)
        type: "alert"

    series

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)
