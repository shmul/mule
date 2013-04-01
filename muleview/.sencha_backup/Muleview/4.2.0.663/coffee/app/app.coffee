Ext.Loader.setPath("Muleview", "app")
Ext.Loader.setPath("Ext.ux", "ux");
Ext.application
  name: "Muleview"
  requires: [
    "Muleview.Settings"
    "Muleview.Events"
    "Ext.container.Viewport"
    "Ext.tree.Panel"
    "Muleview.Mule"
    "Muleview.Graphs"
    "Muleview.RefreshTimer"
  ]

  launch: ->
    Muleview.event = Ext.Function.alias Muleview.Events, "fireEvent"
  autoCreateViewport: true

  controllers: [
    "Viewport"
    "KeysTree"
    "StatusBar"
    "History"
  ]