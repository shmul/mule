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

  autoCreateViewport: true

  controllers: [
    "KeysTree"
    "StatusBar"
    "History"
    "ChartsController"
  ]