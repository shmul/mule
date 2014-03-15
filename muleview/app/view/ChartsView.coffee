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
      weight: 2
      header: true
      id: "lightChartsContainer"
      # bodyCls: "mule-bg"
      region: "east"
      split: true
      width: "20%"
      collapsible: true
      layout:
        type: "vbox"
        align: "stretch"
      items: [] # will be added upone data retrieval
    ,
      xtype: "panel"
      id: "mainChartContainer"
      # bodyCls: "mule-bg"
      tools: [
          type: 'maximize'
          id: "mainChartToolMaximize"
          callback: ->
            Muleview.event "maximize"
        ,
          type: 'restore'
          hidden: true
          id: "mainChartToolRestore"
          callback: ->
            Muleview.event "restore"
      ]
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
          flex: 1
          forceSelection: true
          editable: false
          queryMode: "local"
          displayField: "combinedTitle"
          valueField: "name"
          listConfig:
            getInnerTpl: ->
              '<div class="retention-combobox-item"> <span class="retention-name">{name}</span><span class="retention-title">{title}</span> </div>'
        },

        "-",

        "-",

        {
          text: "Show Subkeys & Alerts"
          id: "subkeysButton"
          icon: "resources/default/images/subkeys.gif"
          enableToggle: true
          pressed: Muleview.Settings.showSubkeys
        },

        "-",

        {
          text: "Show Legend"
          id: "legendButton"
          icon: "resources/default/images/legend.png"
          enableToggle: true
          pressed: Muleview.Settings.showLegend
        },

        "-",

        {
          id: "editAlertsButton"
          text: "Edit Alerts"
          icon: "resources/default/images/alerts.png"
        },

        "-",

        "Auto-Refresh:",

        {
          xtype: "combobox"
          id: "refreshCombobox"
          width: 90
          forceSelection: true
          editable: false
          queryMode: "local"
          displayField: "text"
          valueField: "value"
        },

        {
          xtype: "button"
          id: "refreshButton"
          text: "Now"
          icon: "resources/default/images/refresh.png"
        },

        "-"
      ]
    ,
      xtype: "panel"
      id: "chartPreviewContainer"
      region: "south"
      height: 70
      collapsible: true
      split: true
      collapseMode: "mini"
      header: false
      weight: 1
      layout: "fit"
      items: []
  ]
