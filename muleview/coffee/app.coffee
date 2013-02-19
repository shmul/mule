Ext.Loader.setPath("Muleview", "app")

Ext.application
  name: "Muleview"
  requires: [
    "Ext.container.Viewport",
    "Ext.tree.Panel",
    "Muleview.Settings",
    "Muleview.Mule"
  ]

  controllers: [
    "KeysTree"
  ]

  launch: ->
    Ext.create "Ext.container.Viewport", {
      layout: "border"
      items: [
        {
          xtype: "treepanel"
          id: "keysTree"
          region: "west"
          collapsible: true
          title: "Available Keys"
          width: "20%"
          split: true
          displayField: "name"
          rootVisible: false
        },
        {
          id: "mainPanel"
          xtype: "tabpanel"
          title: "Muleview"
          region: "center"
          layout: "fit"
          items: [ ]
        }
      ]
    }
    Muleview.pullData = @pullData
    Muleview.createGraphs = @createGraphs
    # setInterval(@pullData, Muleview.Settings.updateInterval)

  createGraphs: ->
    tabPanel = Ext.getCmp("mainPanel")
    tabPanel.removeAll();
    Muleview.Mule.getKeyData Muleview.currentKey, (data) =>
      for ret, retData of data[Muleview.currentKey]
        tabPanel.add Ext.create "Ext.panel.Panel",
          title: ret
          layout: "fit"
          items: [
            Ext.create "Muleview.view.MuleChart",
              store: Ext.create "Muleview.store.ChartStore"
                data: data
          ]