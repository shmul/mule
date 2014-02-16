Ext.Loader.setPath "Muleview", "app"
Ext.Loader.setPath "Ext.ux", "ux"

Ext.application
  name: "Muleview"
  autoCreateViewport: true
  requires: [
    "Muleview.Settings"
    "Ext.container.Viewport"
    "Ext.tree.Panel"
    "Muleview.Mule"
    "Muleview.view.ToolTip"
  ]
  controllers: [
    "StatusBar"
    "KeysTree"
    "History"
    "ChartsController"
    "AlertsReportController"
  ]
  launch: ->
    Ext.get("initMask").hide()
    Muleview.event = Ext.Function.alias Muleview.app, "fireEvent"
    Muleview.toUTCDate = (date) ->
      new Date date.getUTCFullYear(),
        date.getUTCMonth(),
        date.getUTCDate(),
        date.getUTCHours(),
        date.getUTCMinutes(),
        date.getUTCSeconds()

    # Form tooltip fix (http://stackoverflow.com/questions/15834689/extjs-4-2-tooltips-not-wide-enough-to-see-contents)
    delete Ext.tip.Tip.prototype.minWidth
