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

  handleClick: (e) ->
    point = @lastHoveredPoint

    if point.series.type == "subkey"
      Muleview.event "viewChange", point.series.key, null

    @fireEvent "topkeyclick"

  renderChart: () ->

    # Remove old components and create container:
    @removeAll()

    # Create new IDs for divs:
    @divs =
      chart: Ext.id()
      legend: Ext.id()

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

    # Create Graph
    @graph = new Rickshaw.Graph
      element: @divs.chart
      interpolation: "linear"
      width: @graphContainer.getWidth()
      height: @graphContainer.getHeight()
      renderer: "multi"
      series: @series

    window.g=@graph #TODO: remove

    Ext.fly(@graph.element).on
      click: @handleClick
      scope: @

    # X Axis:
    new Rickshaw.Graph.Axis.Time
      graph: @graph

    if @mainGraph
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
      element: @sliderContainer.getEl().dom

  createTooltips: ->
    muleChart = @
    graphElement = @graph.element

    FixedTooltip =  Rickshaw.Class.create Rickshaw.Graph.HoverDetail,
      initialize:  ($super, args) ->
        $super(args)
        node = @element.parentNode
        while node != document.body
          node.style.overflow = "visible"
          node = node.parentNode

      render: ($super, args) ->
        $super(args)
        point = (args.points.filter (p) -> p.active).shift()
        muleChart.lastHoveredPoint = point
        Muleview.event "chartMouseover", point
        if muleChart.mainGraph
          cursor = if point.series.type == "subkey" then "pointer" else "default"
        else
          cursor = "pointer"
        graphElement.style.cursor = cursor

      formatter: @formatter

    hover = new FixedTooltip
      graph: @graph

  formatter: (series, x, y, formattedX, formattedY, point) =>
    tplArr = ["
      <table style=\"margin: auto\">
        <tr>
          <td colspan = 2>
            <div class=\"mule-tt-head\" style=\"display: inline-table; margin-right: 3px;\">
              <span class=\"mule-tt-colorbox\" style=\"float: left; background-color: #{series.color} \"></span>
              #{series.name}
            </div>
          </td>
        </tr>
        "
    ]

    addHr = () ->
      tplArr.push("<tr><td colspan=2><hr /></td></tr>")

    addHr()

    addData = (td1, td2) ->
      tplArr.push("
        <tr>
          <td style=\"width: 55px\" ><b>#{td1}:</b></td>
          <td>#{td2}</td>
        </tr>")

    # Time:
    utcOffset = new Date().getTimezoneOffset() * 60
    dateObj = new Date((x + utcOffset) * 1000)
    date = Ext.Date.format(dateObj, "Y-m-d")
    day = Ext.Date.format(dateObj, "l")
    time = Ext.Date.format(dateObj, "H:i:s")

    addData("Value", Ext.util.Format.number(y, ",0"))
    addData("Percent", Ext.util.Format.number(point.value.percent, "0.00%")) if point.series.type == "subkey"
    if point.series.type != "alert"
      addHr()
      addData("Day", day)
      addData("Date", date)
      addData("Time", time)

    tplArr.push("</table>")
    tplArr.join("")

  prepareSeriesData: (keys) ->
    ans = {}
    for key in keys
      ans[key] = []

    @store.each (record) =>
      total = record.get(@topKeys[0])
      for key in keys
        value = record.get(key)
        percent = 100 * value / total
        ans[key].push
          x: record.get("timestamp")
          y: value
          percent: percent
    ans

  createSeries: ->
    palette = new Rickshaw.Color.Palette
      scheme: new Muleview.view.Theme().colors

    keys = Ext.Array.pluck(@alerts || [], "name")
    keys = keys.concat(@topKeys || [])
    keys = keys.concat(@subKeys || [])
    seriesData = @prepareSeriesData(keys)

    series = []

    for alert in (@alerts || [])
      series.push
        name: alert.label
        color: alert.color
        renderer: "line"
        data: seriesData[alert.name]
        type: "alert"

    for topKey in @topKeys
      series.push
        name: @keyLegendName(topKey)
        color: palette.color()
        data: seriesData[topKey]
        type: "topkey"
        key: topKey
        renderer: "line"

    for subKey in (@subKeys || [])
      series.push
        key: subKey
        name: @keyLegendName(subKey)
        color: palette.color()
        data: seriesData[subKey]
        type: "subkey"
        renderer: "stack"


    series

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)
