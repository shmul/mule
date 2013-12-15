Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.container.Container"
  requires: [
    "Muleview.view.Theme"
  ]

  layout: "fit"
  slider: true
  margin: 10
  yAxisWidth: 40
  sliderHeight: 25
  mainGraph: true
  cls: "mule-chart"

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
    if not @hasData
      @add Ext.create "Ext.container.Container",
        layout:
          type: "vbox"
          pack: "center"
          align: "center"

        items: [
          xtype: "label"
          text: "No Data"
        ]
      @setDisabled(true)

      return

    # Remove old components and create container:
    @removeAll()

    # Create new IDs for divs:
    @divs =
      yAxis: Ext.id()
      chart: Ext.id()
      legend: Ext.id()
      slider: Ext.id()

    # Prepare HTML content with new IDs:
    cmpHtml = '
        <div style="display: block">
          <div class="rickshaw-y-axis" id="' + @divs.yAxis + '"> </div>
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
      width: @graphContainer.getWidth() - @yAxisWidth
      height: @graphContainer.getHeight() - @sliderHeight
      renderer: "multi"
      series: @series

    if @mainGraph
      titleContainer = $ "<div />",
        class: "rickshaw-graph-title-container"

      title = $ "<div />",
        class: "rickshaw-graph-title"
        html: @title

      titleContainer.append title
      $(@divs.chart).prepend titleContainer

    Ext.fly(@graph.element).on
      click: @handleClick
      scope: @

    # X Axis:
    new Rickshaw.Graph.Axis.Time
      graph: @graph
      orientation: "bottom"

    if @mainGraph
      # Y Axis:
      new Rickshaw.Graph.Axis.Y
        graph: @graph
        orientation: "left"
        element: @divs.yAxis
        tickFormat: Ext.bind(@numberFormatter, @)

    @createLegend()
    @graph.render()
    @createTooltips()
    @createSlider()

  basicNumberFormatter: Ext.util.Format.numberRenderer(",0")
  numberFormatter: (n) ->
    if n > 1000000 # A million
      n.toExponential(1)
    else
      @basicNumberFormatter(n)

  createLegend: ->
    legendDiv = $(@divs.legend)
    chartDiv = $(@divs.chart)

    legend = new Rickshaw.Graph.Legend
      element: @divs.legend
      graph: @graph

    # Locate the legend at the bottom-left corner of the chart:
    legendDiv.offset
      top: Muleview.Settings.legendTop || chartDiv.offset().top + chartDiv.height() - legendDiv.height() - 50
      left: Muleview.Settings.legendLeft

    legendDiv.hide() if not @showLegend

    legendDiv.draggable
      drag: (event, data)->
        Muleview.Settings.legendTop = data.offset.top
        Muleview.Settings.legendLeft = data.offset.left

    new Rickshaw.Graph.Behavior.Series.Toggle
      graph: @graph
      legend: legend

    new Rickshaw.Graph.Behavior.Series.Highlight
      graph: @graph
      legend: legend
      disabledColor: -> "rgba(0, 0, 0, 0.2)"

    closeButton = $("<div/>",
      class: "rickshaw-legend-close"
    )
    closeButton.click =>
      @setLegend(false)
      @fireEvent "closed"

    legendDiv.prepend closeButton

  setLegend: (visible) ->
    action = if visible then "fadeIn" else "fadeOut"
    $(@divs.legend)[action](300)

  createSlider: ->
    return unless @slider
    new Rickshaw.Graph.RangeSlider
      graph: @graph
      element: @divs.slider

  createTooltips: ->
    muleChart = @
    graphElement = @graph.element

    FixedTooltip =  Rickshaw.Class.create Rickshaw.Graph.HoverDetail,
      initialize:  ($super, args) ->
        $super(args)

        # Make sure all parent nodes allow overflowing so that the tooltip window will be viible:
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

    new FixedTooltip
      graph: @graph

  formatter: (series, x, y, formattedX, formattedY, point) =>
    ans = []

    # Name and value:
    seriesName = series.name
    isSubkey = point.series.type == "subkey"
    value = Ext.util.Format.number(y, ",0")
    percent = Ext.util.Format.number(point.value.percent, "(0.00%)") if isSubkey

    ans.push "<span class=\"mule-tt\">"
    ans.push "<span class=\"mule-tt-colorbox\" style=\"background-color: #{series.color} \"></span>"
    ans.push seriesName
    ans.push percent if isSubkey
    ans.push value
    ans.push "</span>"
    ans.join(" ")

  prepareSeriesData: (keys) ->
    ans = {}
    for key in keys
      ans[key] = []

    @store.each (record) =>
      total = record.get(@topKeys[0])
      for key in keys
        value = record.get(key)
        @hasData ||= value
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
