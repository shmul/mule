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
      bbar: [
          id: "btnSwitchToMultiple"
          text: "Switch to Multiple-Mode"
        ,
          id: "btnSwitchToNormal"
          text: "Switch to Normal-Mode"
          hidden: true
      ]
      items: [
          xtype: "treepanel"
          region: "center"
          id: "keysTree"
          displayField: "name"
          useArrows: true
          rootVisible: false
          lines: true
      ]
    ,
      id: "chartsViewContainer"
      xtype: "panel"
      title: "Chart"
      # FIXME:
      bodyStyle: "background-image: url(resources/default/images/bg.png)"

      region: "center"
      layout: "fit"
    ,
      xtype: "toolbar"
      layout:
        type: "hbox"
        align: "stretch"
        pack: "start"

      collapsible: true
      collapsed: false
      collapseMode: "mini"
      region: "south"
      header: false
      height: 23
      items: [
        {
          xtype: "statusbar"
          margin: 0
          border: false
          id: "statusBar"
          flex: 1
          autoClear: 3000
          defaultText: "Ready"
          items: [
            xtype: "label"
            cls: "statusbar-text"
            id: "lastRefreshLabel"
          ]
        },

        {
          xtype: "container"
          flex: 1
          layout:
            type: "hbox"
            align: "middle"
            pack: "center"

          items: [
          ]
        },

        {
          xtype: "container"
          flex: 1
          layout:
            type: "hbox"
            align: "middle"
            pack: "end"

          items: [
          ]
        },

        {
          icon: "resources/default/images/mule_icon.png"
          handler: ->
            Ext.MessageBox.show
              title: "About"
              msg: "[Add Branding Here]"
              buttons: Ext.Msg.OK
              icon: Ext.Msg.INFO
        }
      ]
  ]
