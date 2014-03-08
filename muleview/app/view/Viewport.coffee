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
            bbar: [
                id: "btnSwitchToMultiple"
                text: "Switch to Multiple-Mode"
              ,
                id: "btnSwitchToNormal"
                text: "Switch to Normal-Mode"
                hidden: true
            ]
        ]
      ,
        id: "chartsView"
        xtype: "MuleChartsView"
        region: "center"
      ,

        id: "alertsReport"
        xtype: "grid"
        region: "south"
        title: "Alerts Status"
        split: true
        collapsible: true
        collapsed: true
        collapseMode: "mini"
        height: "35%"
        columns: [
            # Icon
            width: 20
            sortable: false
            renderer: (value, meta, record) ->
              # This cell gets its icon from the row alert-state-specific class, see viewConfig blow
              meta.tdCls = "icon-cell"
              meta.tdAttr = 'data-qtip="' + record.get("state") + '"'
              ""
          ,
            header: "State"
            dataIndex: "state"
            width: 100
            align: "center"
            renderer: (value, meta) ->
              meta.tdCls = "state-cell"
              value
          ,
            header: "Name"
            dataIndex: "name"
            flex: 2
          ,
            header: "Sum"
            dataIndex: "sum"
            flex: 1
            renderer: Ext.util.Format.numberRenderer(",")
          ,
            header: "Period"
            dataIndex: "formatted_period"
            flex: 1
          ,
            header: "Stale"
            dataIndex: "formatted_stale"
            flex: 1
        ]
        viewConfig:
          getRowClass: (record) ->
            "alert-row-#{record.get("severityClass").toLowerCase()} alert-row-#{record.get("stateClass")}"
      ]
    ,
      xtype: "MuleStatusbar"
      id: "statusBar"
      region: "south"
  ]
