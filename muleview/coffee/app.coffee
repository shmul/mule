Ext.Loader.setPath("Muleview", "app")

Ext.application
  name: "Muleview"
  requires: [
    "Ext.container.Viewport",
    "Ext.tree.Panel",
    "Muleview.Settings",
    "Muleview.Mule"
    "Muleview.Graphs"
  ]

  autoCreateViewport: true

  controllers: [
    "Viewport"
    "KeysTree"
  ]