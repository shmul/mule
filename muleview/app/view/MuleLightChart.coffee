Ext.define "Muleview.view.MuleLightChart",
  extend: "Ext.panel.Panel"
  border: false
  frame: false
  layout: "fit"

  navigate: () ->
    Muleview.event "viewChange", @topKeys, @retention

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      mainGraph: false
      slider: false
      data: @data
      store: @store
      topKeys: @topKeys
      formatter: (series, x, y) ->
        Ext.util.Format.number(y, ",0")
      legend: false
    @chart.on
      topkeyclick: @navigate
      scope: @

    @items = [@chart]
    @tools = [
      type: "prev"
      handler: () => @navigate()
    ]
    @callParent()
