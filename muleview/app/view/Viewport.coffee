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
        id: "chartsViewContainer"
        xtype: "panel"
        title: "Chart"
        bodyCls: "charts-view-container"
        region: "center"
        layout: "fit"
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
              # This cell gets its icon from the row alert-state-specific  class, see viewConfig blow
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
      xtype: "toolbar"
      id: "statusBar"
      height: 25
      region: "south"
      margin: 0
      border: false
      autoClear: 3000
      defaultText: "Ready"
      items: [
          id: "statusLabel"
          xtype: "label"
          flex: 1
          cls: "statusLabel" # needed to reduce CSS headache
          frame: true
          border: true
          value: "Hello world"
          enable: false
        ,
          "-"
        ,
          "Alerts Summary:"
        ,
          ""
        ,
          id: "alertsSummaryCritical"
          alertState: "critical"
          iconCls: "alert-summary-critical"
          text: "Critical: ?"
          toggleGroup: "alersSummaryStates"
        ,
          "-"
        ,
          id: "alertsSummaryWarning"
          alertState: "warning"
          iconCls: "alert-summary-warning"
          text: "Warning: ?"
          toggleGroup: "alersSummaryStates"
        ,
          "-"
        ,
          id: "alertsSummaryNormal"
          alertState: "normal"
          iconCls: "alert-summary-normal"
          text: "Normal: ?"
          toggleGroup: "alersSummaryStates"
        ,
          "-"
        ,
          id: "alertsSummaryStale"
          alertState: "stale"
          iconCls: "alert-summary-stale"
          text: "Stale: ?"
          toggleGroup: "alersSummaryStates"
        ,
          "-"
        ,
          id: "alertsSummaryTotal"
          alertState: "total"
          text: "Total: ?"
          toggleGroup: "alersSummaryStates"
        ,
          "-"
        ,
          xtype: "button"
          id: "alertsSummaryRefresh"
          text: ""
          icon: "resources/default/images/refresh.png"
          tooltip: "Refresh Alerts Now"
          handler: ->
            Muleview.event "alertsChanged"
        ,
          "-"
        ,
          xtype: "container"
          flex: 1
          layout:
            type: "hbox"
            pack: "end"
          items: [
            xtype: "label"
            id: "statusRightLabel"
          ]
        ,
          icon: "resources/default/images/mule_icon.png"
          handler: ->
            Ext.MessageBox.show
              title: "About Mule"
              msg: "<p style=\"text-align:center\"><b>Mule</b> is an <a href=http://github.com/trusteer/mule>open-source</a> project written by <a href=mailto:shmul@trusteer.com>Shmulik Regev</a> & <a href=mailto:dan@carmon.org.il>Dan Carmon</a><br /></p>"
              buttons: Ext.Msg.OK
      ]
  ]
