  Ext.define "Muleview.view.AlertsEditor",
  extend: "Ext.window.Window"

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
        {
          xtype: "displayfield"
          fieldLabel: "Graph"
          name: "graphName"
        }

        {
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
        }
      ]
    formItems.push(@createField(alert)) for alert in Muleview.Settings.alerts

    @form = Ext.create "Ext.form.Panel",
      bodyPadding: 10
      layout:
        type: "vbox"
        align: "stretch"
        pack: "start"
      items: formItems

    [@form]

  formHashFromArray: (arr, base = {}) ->
    base[alert.name] = alert.value for alert in arr
    base

  getForm: ->
    @form.getForm()

  load: (alertsArr) ->
    # Calculate Data:
    hasAlerts = Ext.Object.getKeys(@alerts).length > 0
    data = {
      graphName: "#{@key};#{@retention}"
      isOn: if hasAlerts then "on" else "off"
    }
    data = @formHashFromArray(Muleview.Settings.alerts, data )
    data = @formHashFromArray(@alerts, data) if @alerts
    @getForm().setValues(data)
    @getForm().clearInvalid()
    @updateHeight(hasAlerts)

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
        width: 50
      ,
        text: "Save"
        width: 50
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
        Muleview.event "refresh"
      )

  doCancel: ->
    @close()
