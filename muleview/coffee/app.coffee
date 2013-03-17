Ext.Loader.setPath("Muleview", "app")
Ext.Loader.setPath("Ext.ux", "../ux/");
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
    "Ext.util.History"
  ]

  launch: ->
    Muleview.event = Ext.Function.alias Muleview.Events, "fireEvent"
    Ext.util.History.init ->
      Ext.util.History.on
        change: ->



  autoCreateViewport: true

  controllers: [
    "Viewport"
    "KeysTree"
    "StatusBar"
  ]