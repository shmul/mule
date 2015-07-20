Ext.define "Muleview.view.Preview",
  extend: "Ext.Component"
  initComponent: ->
    @on
      scope: @
      boxready: @renderPreview
    @callParent()

    @mainChart.on
      scope: @
      graphchanged: @attach

    @lightChart.chart.on
      scope: @
      graphchanged: @attach

    @attach()

  attach: ->
    @previewGraph = @lightChart.chart.graph
    @zoomGraph = @mainChart.graph
    @previewGraph?.updateCallbacks.unshift =>
      @fireZoomChange()
    @renderPreview() if @getEl()

  renderPreview: () ->
    this.getEl().dom.innerHTML = ""
    @preview = new Rickshaw.Graph.RangeSlider.Preview
      height: @getHeight()
      width: @getWidth()
      graph: @previewGraph
      element: @getEl().dom

    # Apply the graph's smoother to the preview's graph too:
    @preview.previews[0]?.stackData.hooks.data.push @previewGraph.stackData.hooks.data[0]
    @preview.previews[0]?.update()
    @fireZoomChange()

  fireZoomChange: () ->

    domain = @previewGraph.dataDomain()

    min = @previewGraph.window.xMin
    max = @previewGraph.window.xMax

    min = domain[0] unless min?
    max = domain[1] unless max?

    @zoomGraph.window.xMin = min
    @zoomGraph.window.xMax = max
    @zoomGraph.update()

    Muleview.event "mainChartZoomChange", min, max
