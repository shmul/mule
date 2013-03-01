Ext.define "Muleview.view.Viewport",
  extend: "Ext.container.Viewport"
  layout: "border"
  items: [
      id: "leftPanel"
      xtype: "panel"
      layout: "border"
      region: "west"
      width: "20%"
      split: true
      collapsible: true
      items: [
          xtype: "treepanel"
          region: "center"
          id: "keysTree"
          title: "Available Keys"
          displayField: "name"
          rootVisible: false
        ,
          xtype: "panel"
          title: "Options"
          split: "true"
          region: "south"
          height: "40%"
      ]
    ,
      id: "mainPanel"
      xtype: "tabpanel"
      title: "Main View"
      region: "center"
      layout: "fit"
      tools: [
          type: "maximize"
          id: "mainPanelMaximize"
        ,
          type: "restore"
          id: "mainPanelRestore"
          hidden: true
      ]
    ,
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
  ]
