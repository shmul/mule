Ext.define "Muleview.view.ChartsView",

  extend: "Ext.panel.Panel"
  alias: "widget.MuleChartsView"
  layout: "border"

  requires: [
    "Ext.form.field.ComboBox"
  ]

  items: [
      xtype: "panel"
      title: "Previews"
      header: true
      id: "lightChartsContainer"
      # bodyCls: "mule-bg"
      region: "east"
      split: true
      width: "20%"
      collapsible: false
      layout:
        type: "vbox"
        align: "stretch"
      items: [] # will be added upone data retrieval
    ,
      xtype: "panel"
      id: "mainChartContainer"
      # bodyCls: "mule-bg"
      region: "center"
      header: true
      title: "Graph"
      bodyPadding: 5
      layout:
        type: "vbox"
        align: "stretch"
      items: []
      tbar: [
        "Show:",

        {
          xtype: "combobox"
          id: "retentionsMenu"
          width: 250
          forceSelection: true
          editable: false
          queryMode: "local"
          displayField: "combinedTitle"
          valueField: "name"
        },

        {
          text: "Subkeys"
          id: "subkeysButton"
          icon: "resources/default/images/subkeys.gif"
          enableToggle: true
          pressed: Muleview.Settings.showSubkeys
        },

        {
          text: "Legend"
          id: "legendButton"
          icon: "resources/default/images/legend.png"
          enableToggle: true
          pressed: Muleview.Settings.showLegend
        },

        "->",

        "Auto-Refresh:",

        {
          xtype: "combobox"
          width: 90
          forceSelection: true
          editable: false
          queryMode: "local"
          displayField: "text"
          valueField: "value"
          # listeners:
          #   change: Ext.bind(@updateRefreshTimer, @)
          #   boxready: (me) ->
          #     record = me.getStore().findRecord("value", Muleview.Settings.updateInterval)
          #     me.select(record) if record
          store:
            fields: ["text", "value"]
            data: [{text: "Disabled", value: -1}]
            # .concat(
          #     {
          #       text: secs,
          #       value: secs
          #     } for secs in [
          #       10
          #       30
          #       60
          #       60 * 5
          #       60 * 10
          #       60 *15
          #       60 * 60
          #     ]
          #   )
        },

        {
          xtype: "button"
          text: "Now"
          icon: "resources/default/images/refresh.png"
          handler: @refresh
        },

        "-"
      ]
  ]
