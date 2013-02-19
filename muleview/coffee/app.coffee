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
    Muleview.createGraphs = @createGraphs
    Muleview.createMuleRecord = @createMuleRecord
    # setInterval(@pullData, Muleview.Settings.updateInterval)

  createGraphs: ->
    tabPanel = Ext.getCmp("mainPanel")
    tabPanel.removeAll();
    Muleview.Mule.getKeyData Muleview.currentKey, (data) =>
      # Data is in the form "key => retention => data", so we need to reverse it to retention-based first:
      retentions = {}
      for key, rets of data
        for retention, retentionData of rets
          retentions[retention] ||= {}
          retentions[retention][key] = retentionData
      # Now, create a graph for each retention:
      for ret, retData of retentions

        # Create the tab containing the chart:
        tabPanel.add Ext.create "Ext.panel.Panel",
          title: ret
          layout: "fit"
          items: [
            Ext.create "Muleview.view.MuleChart",
              data: retData
              topKey: Muleview.currentKey
          ]
      tabPanel.setActiveTab(0)