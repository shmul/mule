Ext.Loader.setPath("Muleview", "app")

Ext.application
  name: "Muleview"
  requires: [
    "Muleview.Settings",
    "Ext.container.Viewport",
    "Ext.tree.Panel",
    "Muleview.Mule"
    "Muleview.Graphs"
  ]

  autoCreateViewport: true

  launch: ->
    console.log("app.coffee\\ 16: <HERE>");
    # TODO: find some other solution
    Muleview.Mule.askMule "alert", (alerts) ->
      Muleview.alerts = alerts
      console.log('app.coffee\\ 18: Muleview.alerts:', Muleview.alerts);

  controllers: [
    "Viewport"
    "KeysTree"
  ]