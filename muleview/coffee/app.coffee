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

  controllers: [
    "Viewport"
    "KeysTree"
  ]