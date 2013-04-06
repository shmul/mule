Ext.define "Muleview.view.Viewport",
  extend: "Ext.container.Viewport"
  layout: "border"
  requires: [
    "Muleview.view.AlertsEditor"
    "Muleview.view.ChartsView"
    "Ext.layout.container.Border"
    "Ext.tab.Panel"
    "Ext.ux.statusbar.StatusBar"
    "Ext.form.Label"
  ]

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
          # useArrows: true
          rootVisible: false
          lines: true
        ,
          xtype: "tabpanel"
          region: "south"
          height: 280
          split: "true"
          collapsible: true
          collapsed: true
          title: "Options"
          layout: "fit"
          items: [
              {
                xtype: "muleviewAlertsEditor"
                id: "alertsEditor"
              }
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
      id: "chartsViewContainer"
      xtype: "panel"
      title: "Chart"
      region: "center"
      layout: "fit"
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
        {
          xtype: "statusbar"
          id: "statusBar"
          autoClear: 3000
          defaultText: "Ready"
          items: [
              xtype: "label"
              cls: "statusbar-text"
              id: "lastRefreshLabel"
            ,
              "-"
            ,
              xtype: "tool"
              type: "minimize"
              tooltip: "Collapse status bar"
              handler: (event, toolEl, owner) ->
                owner.up().collapse()
          ]
        }
      ]

  ]
