Ext.define "Muleview.view.MuleChartPanel",
  extend: "Ext.panel.Panel"
  layout: "fit"
  header: false

  requires: [
    "Muleview.view.ZoomSlider"
    "Muleview.view.MuleChart"
  ]

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      showAreas: true
      keys: @keys
      topKey: @topKey
      alerts: @alerts
      store: @store
    @items = [@chart]

    @bbar =
      layout:
        type: "hbox"
      items: [
          slider = Ext.create "Muleview.view.ZoomSlider",
            flex: 1
            store: @store
        ,
          xtype: "button"
          text: "Reset"
          handler: ->
            slider.reset()
      ]
    @callParent()
