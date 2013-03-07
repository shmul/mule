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
      title: "Available Keys"
      items: [
          xtype: "treepanel"
          region: "center"
          id: "keysTree"
          displayField: "name"
          useArrows: true
          rootVisible: false
        ,
          xtype: "tabpanel"
          region: "south"
          height: "40%"
          split: "true"
          collapsible: true
          collapsed: true
          title: "Options"
          layout: "fit"
          items: [
              Ext.create("Muleview.view.AlertsEditor",
                id: "alertsEditor"
              )
            ,
              {
                xtype: "panel"
                layout:
                  type: "hbox"
                  align: "middle"
                  pack: "center"
                title: "Event Labels"
                items: [
                  xtype: "container"
                  html: "(Coming soon)"
                ]
              }
          ]
      ]
    ,
      id: "mainPanel"
      xtype: "tabpanel"
      title: "Main View"
      region: "center"
      layout: "fit"
      tools: [
          type: "refresh"
          tooltip: "Reload Graphs"
          id: "mainPanelRefresh"
        ,
          type: "maximize"
          tooltip: "Maximize Graph"
          id: "mainPanelMaximize"
        ,
          type: "restore"
          tooltip: "Restore"
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
      title: "Previews"
      layout:
        type: "vbox"
        align: "stretch"
      defaults:
        flex: 1
    ,
      xtype: "panel"
      layout: "fit"
      collapsible: true
      collapsed: false
      collapseMode: "mini"
      region: "south"
      header: false
      height: 23
      items: [
        Ext.create "Ext.ux.statusbar.StatusBar",
          xtype: "statusbar"
          items: [
              xtype: "tool"
              type: "minimize"
              tooltip: "Collapse status bar"
              handler: (event, toolEl, owner) ->
                owner.up().collapse()
          ]
      ]

  ]
