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
    # TODO: find some other solution
    Muleview.queryAlerts = ->
      Muleview.Mule.askMule "alert", (alerts) ->
        Muleview.alerts = alerts
    Muleview.queryAlerts()

  controllers: [
    "Viewport"
    "KeysTree"
  ]