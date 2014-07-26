Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.container.Container"
  requires: [
    "Muleview.view.Theme"
  ]

  layout: "fit"
  margin: 10
  yAxisWidth: 40
  mainGraph: true
  cls: "mule-chart"
  interpolation: "linear"

  initComponent: ->
    @series = @createSeries()

    @on
      boxready: @renderChart
      resize: @renderChart
      scope: @

    @callParent()

  handleClick: (e) ->
    point = @lastHoveredPoint
    Muleview.event "topkeyclick", @, point?.series.type, point

  renderChart: () ->
    # If there's no data - show an empty "No Data" pane:
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

    # Prepare HTML content with new IDs:
    cmpHtml = '
        <div style="display: block">
          <div class="rickshaw-y-axis" id="' + @divs.yAxis + '"> </div>
          <div class="rickshaw-chart" id="' + @divs.chart + '"> </div>
          <div class="rickshaw-legend" id="' + @divs.legend + '"> </div>
        </div>
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
      height: @graphContainer.getHeight() - 10
      renderer: "multi"
      interpolation: @interpolation
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


    @createSmoother()
    @graph.updateCallbacks.push () =>
      @drawAnomalies
      @drawAlerts()
    @graph.render()
    @createTooltips()
    @fireEvent("graphchanged")

  createSmoother: () ->
    @graph.stackData.hooks.data.push
      name: 'smoother'
      orderPosition: 50,
      f: (data) =>
        data = Ext.clone(data)
        number_of_points = data[Ext.Object.getKeys(data)[0]].length
        max_points = Muleview.Settings.maxNumberOfChartPoints || 1000
        points_to_remove = @getPointsToRemove(number_of_points, max_points)
        for series in data
          for index in points_to_remove by -1
            agg = series[index + 1]
            if not agg.is_agg
              agg = {
                is_agg: true,
                points: [series[index + 1]]
              }
              series[index + 1] = agg
            agg.points.push series.splice(index, 1)[0]

          for index in [0...series.length]
            if series[index].is_agg
              series[index] = {
                x: Ext.Array.mean(Ext.Array.pluck(series[index].points, "x"))
                y: Ext.Array.mean(Ext.Array.pluck(series[index].points, "y"))
              }
        data


  getPointsToRemove: (number_of_points, max_points) ->
    ans = []
    number_of_points_to_remove = Math.abs(Math.min(0,  max_points - number_of_points))
    ratio = number_of_points / number_of_points_to_remove
    ans.push Math.floor(index * ratio) for index in [0...number_of_points_to_remove]
    ans

  updateData: (data) ->
    for series in @graph.series
      series.data = data[series.key] if data[series.key]
    @graph.update()


  updateAlerts: (newAlerts) ->
    @alerts = newAlerts
    @drawAlerts()

  drawAlerts: () ->
    alertDiv?.parentNode.removeChild(alertDiv) while alertDiv = @alertDivs?.shift()
    @alertDivs ||= []
    for alert in @alerts || []
      div = document.createElement("div")
      div.tytle = alert.name
      div.className = "rickshaw-alert alert-" + alert.name
      div.style.top = "" + @graph.y(alert.value) + "px"
      div.style["border-color"] = alert.color
      @alertDivs.push(div)
      @graph.element.appendChild(div)
  drawAnomalies: () ->
    anomalies = []
    for key in @topKeys
      anomalies = Ext.Array.union(anomalies, Muleview.Anomalies.getAnomaliesForKey(@key))
    for anomaly in anomalies
      @addTimeTag(anomaly)


  basicNumberFormatter: Ext.util.Format.numberRenderer(",0")
  numberFormatter: (n) ->
    if n > 1000000 # A million
      n.toExponential(1)
    else
      @basicNumberFormatter(n)

  createLegend: ->
    return unless @mainGraph
    legendDiv = $(@divs.legend)
    chartDiv = $(@divs.chart)

    legend = new Rickshaw.Graph.Legend
      element: @divs.legend
      graph: @graph

    # Locate the legend at the bottom-left corner of the chart:
    legendDiv.offset
      top: Muleview.Settings.legendTop || chartDiv.offset().top + chartDiv.height() - legendDiv.height() - 50
      left: Muleview.Settings.legendLeft

    legendDiv.hide() if not Muleview.Settings.showLegend

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

  createTooltips: ->
    muleChart = @
    graphElement = @graph.element

    FixedTooltip = Rickshaw.Class.create Rickshaw.Graph.HoverDetail,
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
        cursor = point.series.type == "subkey" && muleChart.mainGraph && "pointer" || "default"
        graphElement.style.cursor = cursor

      formatter: (series, x, y, formattedX, formattedY, point) ->
        ans = muleChart.tooltipTpl.apply
          seriesName: series.name
          isSubkey: point.series.type == "subkey"
          value: Ext.util.Format.number(y, ",0")
          percent: "" # Ext.util.Format.number(point.value.percent, "(0.00%)") if isSubkey
          seriesColor: series.color
        ans

    new FixedTooltip
      graph: @graph

  tooltipTpl: new Ext.XTemplate('
    <span class="mule-tt">
      {seriesName}
      <tpl if="isSubkey">{percent}</tpl>
      {value}
      <span class="mule-tt-colorbox" style="background-color: {seriesColor}"></span>
  </span>')


  prepareSeriesData: (keys) ->
    ans = {}
    for key in keys
      ans[key] = []

    @store.each (record) =>
      total = record.get(@topKeys[0])
      for key in keys
        value = record.get(key)
        @hasData ||= value?
        percent = 100 * value / total
        ans[key].push
          x: record.get("timestamp")
          y: value
          percent: percent
    ans

  createSeries: ->
    palette = new Rickshaw.Color.Palette
      scheme: new Muleview.view.Theme().colors

    seriesData = @data
    series = []

    for subKey in (@subKeys || [])
      series.push
        key: subKey
        name: @keyLegendName(subKey)
        color: palette.color()
        data: seriesData[subKey]
        type: "subkey"
        renderer: "stack"

    for topKey in @topKeys
      @hasData ||= seriesData[topKey]?.length > 0
      series.push
        name: @keyLegendName(topKey)
        color: palette.color()
        data: seriesData[topKey]
        type: "topkey"
        key: topKey
        renderer: "line"

    series

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)
