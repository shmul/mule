Ext.define "Muleview.view.AlertsEditor",
  extend: "Ext.form.Panel"
  title: "Alerts"
  requires: [
    "Muleview.Settings"
  ]
  bodyPadding: 10
  layout: "auto"
  overflowY: "auto"
  defaults:
    width: 200
  items: [
      xtype: "hidden"
      name: "period"
      value: "1m"
    ,
      xtype: "hidden"
      name: "stale"
      value: "1m"
  ]
  initComponent: ->
    for alert in Muleview.Settings.alerts
      @items.push
        xtype: "numberfield"
        name: alert.name
        allowBlank: false
        fieldLabel: alert.label
        value: 0
    @items.push
      xtype: "button"
      text: "Update"
      handler: =>
        console.log('AlertsEditor.coffee\\ 26: Muleview.currentkey:', Muleview.currentkey);
        console.log('AlertsEditor.coffee\\ 27: Muleview.currentRetention:', Muleview.currentRetention);
        url = Muleview.Mule.getAlertCommandUrl(Muleview.currentKey, Muleview.currentRetention)
        @submit(
          url: url
          method: "PUT"
        )
    @callParent()
