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
        },
        {
          id: "mainPanel"
          xtype: "panel"
          title: "Muleview"
          region: "center"
          layout: "fit"
          items: [ ]
        }
      ]
    }
