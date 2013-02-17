Ext.application
  requires: [
    "Ext.container.Viewport",
  ]

  name: "Muleview"
  controllers: [
    "Main"
  ]
  launch: ->
    Ext.create "Ext.container.Viewport", {
      layout: "border"
      items: [
        {
          id: "keysTree"
          region: "west"
          collapsible: true #TODO CHECK
          title: "Available Keys"
          width: "20%"
          split: true
          displayField: "name"
          listeners:
            selectionchange: -> #pullData
          # store: treeStore
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
