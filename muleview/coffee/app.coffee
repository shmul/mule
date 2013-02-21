Ext.Loader.setPath("Muleview", "app")

Ext.application
  name: "Muleview"
  requires: [
    "Ext.container.Viewport",
    "Ext.tree.Panel",
    "Muleview.Settings",
    "Muleview.Mule"
    "Muleview.Graphs"
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
          title: "Main View"
          region: "center"
          layout: "fit"
          items: [ ]
        },
        {
          id: "rightPanel"
          width: "20%"
          split: true
          xtype: "panel"
          region: "east"
          collapsible: true
          title: "Other Views"
          layout:
            type: "vbox"
            align: "stretch"
          defaults:
            flex: 1
        }
      ]
    }
    # setInterval(@pullData, Muleview.Settings.updateInterval)
