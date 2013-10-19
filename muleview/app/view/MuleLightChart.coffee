Ext.define "Muleview.view.MuleLightChart",
  extend: "Ext.panel.Panel"
  border: false
  frame: false
  layout: "fit"

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      mainGraph: false
      slider: false
      data: @data
      store: @store
      topKeys: @topKeys
      legend: false

    @items = [@chart]
    @tools = [
      type: "prev"
      handler: () =>
        Muleview.event "viewChange", @topKeys, @retention
    ]
    @callParent()
