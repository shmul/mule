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
    Muleview.queryAlerts = (callback)->
      Muleview.Mule.askMule "alert", (alerts) ->
        Muleview.alerts = alerts
        callback?()
    Muleview.queryAlerts()

  controllers: [
    "Viewport"
    "KeysTree"
  ]