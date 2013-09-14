Ext.Loader.setPath "Muleview", "app"
Ext.Loader.setPath "Ext.ux", "ux"

Ext.application
  name: "Muleview"
  requires: [
    "Muleview.Settings"
    "Ext.container.Viewport"
    "Ext.tree.Panel"
    "Muleview.Mule"
    "Muleview.RefreshTimer"
    "Muleview.view.ToolTip"
  ]

  launch: ->
    Muleview.event = Ext.Function.alias Muleview.app, "fireEvent"
    Muleview.toUTCDate = (date) ->
      new Date date.getUTCFullYear(),
        date.getUTCMonth(),
        date.getUTCDate(),
        date.getUTCHours(),
        date.getUTCMinutes(),
        date.getUTCSeconds()

  autoCreateViewport: true

  controllers: [
    "KeysTree"
    "StatusBar"
    "History"
    "ChartsController"
    "AlertsReportController"
  ]
