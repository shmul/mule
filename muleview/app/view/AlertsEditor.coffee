  Ext.define "Muleview.view.AlertsEditor",
  extend: "Ext.window.Window"
  icon: "resources/default/images/alerts.png"
  modal: true
  resizable: false

  requires: [
    "Muleview.Settings"
    "Muleview.view.MuleTimeField"
    "Ext.form.field.Number"
    "Ext.form.field.Display"
    "Ext.container.Container"
  ]

  bodyPadding: 10
  width: 300
  height: 300

  layout: "fit"
  autoScroll: true

  title: "Alerts"
  defaults:
    margin: "5px 0px 0px 0px"
  items: ->
    formItems = [
          xtype: "displayfield"
          fieldLabel: "Graph"
          name: "name"
        ,
          xtype: "container"
          layout:
            type: "hbox"
            align: "middle"

          defaults:
            flex: 1

          items: [
              xtype: "container"
              html: "Alerts"
            ,
              xtype: "radio"
              name: "isOn"
              boxLabel: "Off"
              inputValue: "off"
              listeners:
                change: (me, val) =>
                  @updateHeight(!val)
            ,
              xtype: "radio"
              name: "isOn"
              boxLabel: "On"
              inputValue: "on"
          ]

        ,
          name: "critical_high"
          fieldLabel: "Critical High"
        ,
          name: "warning_high"
          fieldLabel: "Warning High"
        ,
          name: "warning_low"
          fieldLabel: "Warning Low"
        ,
          name: "critical_low"
          fieldLabel: "Critical Low"
        ,
          xtype: "muletimefield"
          name: "period"
          fieldLabel: "Period"
        ,
          xtype: "muletimefield"
          name: "stale"
          fieldLabel: "Stale"
      ]

    @form = Ext.create "Ext.form.Panel",
      bodyPadding: 10
      layout:
        type: "vbox"
        align: "stretch"
        pack: "start"
      defaults:
        allowBlank: false
        xtype: "numberfield"
      items: formItems

    [@form]

  formHashFromArray: (arr, base = {}) ->
    base[alert.name] = alert.value for alert in arr
    base

  getForm: ->
    @form.getForm()

  load: () ->
    debugger
    alert = Ext.StoreManager.get("alertsStore").findRecord("name", @alertName)
    alert ||= Ext.create "Muleview.model.Alert",
      name: @alertName
    @form.loadRecord(alert)
    @getForm().clearInvalid()
    @updateHeight(alert.get("isOn"))

  updateHeight: (mode)->
    height = if mode then 315 else 154
    @setHeight height

  createField: (alert) ->
    ans =
      allowBlank: false
      name: alert.name
      value: 0
      fieldLabel: alert.label
    if alert.time
      ans.xtype = "muletimefield"
    else
      ans.xtype = "numberfield"
    ans

  bbar: ->
    [
        "->"
      ,
        text: "Cancel"
        handler: => @doCancel()
        icon: "resources/default/images/cancel.png"
        width: 76
      ,
        text: "Save"
        icon: "resources/default/images/ok.png"
        width: 76
        handler: => @doSave()
    ]

  initComponent: ->
    @items = @items()
    @bbar = @bbar()
    @callParent()
    @load()

  doSave: ->
    alertsOn = @getForm().getValues().isOn
    if alertsOn == "on"
      @doMuleAction ("PUT") if @getForm().isValid()
    else if alertsOn == "off"
      @doMuleAction ("DELETE") if @getForm().isValid()

  doMuleAction: (method) ->
    @getForm().submit(
      url: Muleview.Mule.getAlertCommandUrl(@key, @retention)
      method: method
      success: =>
        @close()
        Muleview.event "alertsChanged"
        Muleview.event "refresh"
      )

  doCancel: ->
    @close()
