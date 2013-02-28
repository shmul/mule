Ext.define "Muleview.view.Viewport",
  extend: "Ext.container.Viewport"
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
      tools: [
          type: "maximize"
          handler: ->
            console.log("app.coffee\\ 41: <HERE>");
      ]
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
