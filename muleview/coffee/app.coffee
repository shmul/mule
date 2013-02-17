Ext.Loader.setPath("Muleview", "app")

Ext.application
  name: "Muleview"
  requires: [
    "Ext.container.Viewport",
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
          xtype: "treeview"
          id: "keysTree"
          region: "west"
          collapsible: true
          title: "Available Keys"
          width: "20%"
          split: true
          displayField: "name"
        }),
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
  # setInterval(Ext.bind(this.pullData, this), this.settings.updateInterval)

  pullData: ->
    console.log("app.coffee\\ 40: <HERE>");
