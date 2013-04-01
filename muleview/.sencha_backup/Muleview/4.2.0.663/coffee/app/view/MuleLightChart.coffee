Ext.define "Muleview.view.MuleLightChart",
  extend: "Ext.panel.Panel"
  border: false
  frame: false
  layout: "fit"

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      data: @data
      keys: @keys
      store: @store
      topKey: @topKey
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
        Muleview.event "graphRequest", Muleview.currentKey, @retention
    ]

    @callParent()