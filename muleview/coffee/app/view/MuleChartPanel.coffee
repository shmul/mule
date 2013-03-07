Ext.define "Muleview.view.MuleChartPanel",
  extend: "Ext.panel.Panel"
  layout: "fit"

  initComponent: ->
    slider = Ext.create "Muleview.view.ZoomSlider",
      store: @store

    @chart = Ext.create "Muleview.view.MuleChart",
      showAreas: true
      keys: @keys
      alerts: @alerts
      store: @store
    @items = [@chart]

    @bbar =
      layout:
        type: "hbox"
      items: [
          slider
        ,
          xtype: "button"
          text: "Reset"
          handler: ->
            slider.reset()
      ]
    @callParent()
