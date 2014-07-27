Ext.define "Muleview.view.Viewport",
  extend: "Ext.container.Viewport"
  layout: "border"
  requires: [
    "Muleview.view.AlertsEditor"
    "Muleview.view.ChartsView"
    "Muleview.view.MuleReports"
    "Ext.layout.container.Border"
    "Ext.tab.Panel"
    "Ext.ux.statusbar.StatusBar"
    "Ext.form.Label"
    "Muleview.view.Statusbar"
  ]

  items: [
      xtype: "container",
      region: "center"
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
            lines: true
            tbar: [
                id: "btnSwitchToMultiple"
                text: "Switch to Multiple-Mode"
                flex: 1
              ,
                id: "btnSwitchToNormal"
                text: "Switch to Normal-Mode"
                hidden: true
                flex: 1
            ]
          ,
            id: "keysTreePbar"
            xtype: "progressbar"
            value: 1
            text: ""
            region: "south"
            hidden: true
        ]
      ,
        id: "chartsView"
        xtype: "MuleChartsView"
        region: "center"
      ,
        xtype: "MuleReports"
        id: "reportsView"
        region: "south"
        split: true
        collapsible: true
        collapsed: true
        collapseMode: "mini"
        height: "35%"

      ]
    ,
      xtype: "MuleStatusbar"
      id: "statusBar"
      region: "south"
  ]
