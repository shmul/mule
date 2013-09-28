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

  title: "Alerts"
  bodyPadding: 10
  width: 300
  height: 320
  layout: "fit"
  autoScroll: true

  defaults:
    margin: "5px 0px 0px 0px"

  items: ->
    formItems = [
          xtype: "displayfield"
          fieldLabel: "Graph"
          name: "name"
        ,
          xtype: "checkbox"
          fieldLabel: "Enable Alert"
          name: "isOn"
          boxLabel: "Enable"
          listeners:
            change: (me, val) =>
              @updateHeight(val)
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
      trackResetOnLoad: true
      layout:
        type: "vbox"
        align: "stretch"
        pack: "start"
      defaults:
        allowBlank: false
        xtype: "numberfield"
      items: formItems
      listeners:
        validitychange: (me, valid) =>
          Ext.getCmp("alertsEditorSaveButton").setDisabled(!valid)

    [@form]

  getForm: ->
    @form.getForm()

  load: () ->
    alertName = @key + ";" + @retention
    @alert = Ext.StoreManager.get("alertsStore").getById(alertName)
    @alert ||= @createDefaultAlert()
    @form.loadRecord(@alert)
    @getForm().clearInvalid()
    @updateHeight(@alert.get("isOn"))

  createDefaultAlert: () ->
    max = @store.max(@key)
    min = @store.min(@key)
    step = new Muleview.model.Retention(@retention).getStep()
    Ext.create "Muleview.model.Alert",
      name: @key + ";" + @retention
      warning_low: min
      critical_low: min * 0.9
      warning_high: max
      critical_high: max * 1.1
      stale:  step * 2
      period: step * 2
      isOn: false

  updateHeight: (mode)->
    height = if mode then 320 else 154
    @setHeight height

    # Defering the centering due to a mysterious bug
    setTimeout( =>
      @center()
    , 10)

  bbar: ->
    [
        text: "Reset"
        icon: "resources/default/images/reset.png"
        flex: 1
        handler: =>
          @getForm().reset()
      ,
        "-"
      ,
        text: "Auto"
        tooltip: "Set values according to currently known graph data"
        flex: 1
        icon: "resources/default/images/wand.png"
        handler: =>
          @adjust()
      ,
        "-"
      ,
        text: "Cancel"
        handler: => @doCancel()
        icon: "resources/default/images/cancel.png"
        flex: 1
      ,
        "-"
      ,
        id: "alertsEditorSaveButton"
        text: "Save"
        icon: "resources/default/images/ok.png"
        flex: 1
        handler: => @doSave()
    ]

  adjust: ->
    adjustedAlert = @createDefaultAlert()
    adjustedAlert.set("isOn", true)
    @getForm().getFields().each (field) =>
      field.setValue(adjustedAlert.get(field.name))

  initComponent: ->
    @items = @items()
    @bbar = @bbar()
    @callParent()
    @load()

  doSave: ->
    @getForm().updateRecord()
    alertsOn = @alert.get("isOn")
    if alertsOn
      @doMuleAction("PUT") if @getForm().isValid()
    else
      @doMuleAction("DELETE")

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
