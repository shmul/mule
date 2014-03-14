Ext.define "Muleview.view.MuleLightChart",
  extend: "Ext.panel.Panel"
  border: false
  frame: false
  layout: "fit"
  cls: "mule-chart mule-lightchart"

  navigate: () ->
    Muleview.event "viewChange", @topKeys, @retention

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      yAxisWidth: 0
      mainGraph: false
      data: @data
      topKeys: @topKeys
      formatter: (series, x, y) ->
        Ext.util.Format.number(y, ",0")
    @chart.on
      topkeyclick: @navigate
      scope: @

    @items = [@chart]
    @tools = [
      type: "prev"
      handler: () => @navigate()
    ]
    @callParent()
