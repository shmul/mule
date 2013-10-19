Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.container.Container"
  createDiv: (cls) ->
    Ext.create "Ext.Component",
      autoEl: "div"
      cls: cls
  items: ->
    [
        xtype: "container"
        flex: 1
        autoEl: "div"
        cls: "rickshaw-chart-container"
        items: [
          @chart = @createDiv("rickshaw-chart")
          @chartYAxis = @createDiv("rickshaw-y-axis")
        ]
      ,
        @legend = @createDiv("rickshaw-legend")
    ]

  initComponent: ->
    @items = @items()
    @on
      boxready: @renderChart
      scope: @

    window.c = @ # TODO: remove

    @callParent()

  renderChart: ->
    @graph = new Rickshaw.Graph
      element: @chart.getEl().dom
      width: @getWidth() - 100
      height: @getHeight()
      renderer: "multi"
      dotSize: 5
      series: @makeSeries()

    axisX = new Rickshaw.Graph.Axis.Time
      graph: @graph

    axisY = new Rickshaw.Graph.Axis.Y
      graph: @graph
      orientation: "left"
      tickFormat: Rickshaw.Fixtures.Number.formatKMBT
      element: @chartYAxis.getEl().dom

    if @showLegend
      legend = new Rickshaw.Graph.Legend
        element: document.querySelector("#rickshaw-legend")
        graph: @graph

    @graph.render()

  seriesData: (series) ->
    ans = []
    @store.each (record) ->
      ans.push
        x:  record.get("timestamp") * 1000
        y: record.get(series)
    ans

  makeSeries: ->
    palette = new Rickshaw.Color.Palette()
    series = []

    for topKey in @topKeys
      series.push
        name: @keyLegendName(topKey)
        color: palette.color()
        data: @seriesData(topKey)
        renderer: "line"

    for subKey in (@subKeys || [])
      series.push
        name: @keyLegendName(subKey)
        color: palette.color()
        data: @seriesData(subKey)
        renderer: "stack"

    series

  keyLegendName: (key) ->
    key.substring(key.lastIndexOf(".") + 1)
