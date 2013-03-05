Ext.define "Muleview.view.AlertsEditor",
  extend: "Ext.form.Panel"
  requires: [
    "Muleview.Settings"
  ]
  bodyPadding: 10
  layout:
    type: "vbox"
    align: "stretch"
    pack: "start"
  overflowY: "auto"
  title: "Alerts"

  items: []

  formHashFromArray: (arr, base = {}) ->
    base[alert.name] = alert.value for alert in arr
    base

  load: (alertsArr) ->
    data = @formHashFromArray(Muleview.Settings.alerts)
    data = @formHashFromArray(alertsArr, data) if alertsArr
    @getForm().setValues(data)

  createField: (alert) ->
    ans =
      allowBlank: false
      name: alert.name
      value: 0
      fieldLabel: alert.label
    if alert.time
      ans.xtype = "textfield"
      ans.regex = /[0-9]+[mhs]?/
    else
      ans.xtype = "numberfield"
    ans

  initComponent: ->
    for alert in Muleview.Settings.alerts
      @items.push @createField(alert)
    @items.push
      xtype: "button"
      text: "Update"
      handler: =>
        url = Muleview.Mule.getAlertCommandUrl(Muleview.currentKey, Muleview.currentRetention)
        @submit(
          url: url
          method: "PUT"
          success: ->
            Muleview.queryAlerts( ->
              Muleview.Graphs.createGraphs()
            )
        )
    @callParent()
