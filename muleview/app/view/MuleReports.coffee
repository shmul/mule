Ext.define "Muleview.view.MuleReports",
  extend: "Ext.panel.Panel"
  requires: [
    "Muleview.Anomalies"
  ]
  alias: "widget.MuleReports"
  layout: "border"
  items: [
    {
      xtype: "grid"
      id: "anomaliesReport"
      region: "east"
      width: "30%"
      split: true
      title: "Anomalies"
      store: Muleview.Anomalies.getStore()
      collapsible: true
      collapsed: false
      listeners:
        selectionchange: (me, selection) ->
          return if Ext.isEmpty(selection)
          anomaly = selection[0]
          Muleview.event "viewChange", anomaly.get("key"), anomaly.get("retention")

      columns: [
          dataIndex: "name",
          header: "Name"
          flex: 1
        ,
          xtype: "datecolumn"
          dataIndex: "latestTimestamp"
          flex: 1
          header: "Latest Anomaly"
          format: "l, o-m-j H:i:s"
      ]

    }
    ,{
      id: "alertsReport"
      xtype: "grid"
      region: "center"
      title: "Alerts Status"
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
    }
  ]
