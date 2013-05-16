Ext.define "Muleview.view.MuleLightChart",
  extend: "Ext.panel.Panel"
  border: false
  frame: false
  layout: "fit"

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      data: @data
      store: @store
      topKeys: @topKeys
      legend: false
      showAreas: false
      highlight: false
      timeLabel:
        renderer: ->
          ""
    adjustEnd: false
    @items = [@chart]
    @tools = [
      type: "prev"
      handler: () =>
        Muleview.event "viewChange", @topKeys, @retention
    ]
    @callParent()
