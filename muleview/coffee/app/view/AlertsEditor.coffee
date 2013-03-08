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

  items: [
      xtype: "displayfield"
      fieldLabel: "Graph"
      name: "graphName"
  ]

  formHashFromArray: (arr, base = {}) ->
    base[alert.name] = alert.value for alert in arr
    base

  load: (curKey, curRet, alertsArr) ->
    # Calculate Data:
    data = {
      graphName: "#{curKey};#{curRet}"
    }
    data = @formHashFromArray(Muleview.Settings.alerts, data )
    data = @formHashFromArray(alertsArr, data) if alertsArr
    @getForm().setValues(data)

    # Display correct items:
    @updateButtons (if alertsArr then "edit" else "create")
    @fieldsContainer.setVisible(alertsArr)

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
    # Fields:
    fields = []
    for alert in Muleview.Settings.alerts
      fields.push @createField(alert)

    # Field container
    @fieldsContainer = Ext.create "Ext.container.Container",
      layout:
        type: "vbox"
        align: "stretch"
        pack: "start"

      items: fields
      border: false
      hidden: true

    @items.push @fieldsContainer

    # Buttons:
    @buttonsContainer = Ext.create "Ext.container.Container",
      border: false
      layout:
        type: "hbox"
        pack: "start"
      defaults:
        xtype: "button"
        margin: "0px 5px 0px 0px"
        hidden: true
      items: [
            text: "Save"
            handler: => @doUpdate()
            showInMode: ["edit", "creating"]
        ,
            text: "Delete"
            handler: => @doDelete()
            showInMode: ["edit"]
        ,
            text: "Set Alerts"
            handler: => @doCreate()
            showInMode: ["create"]
        ,
            text: "Cancel"
            handler: => @doCancel()
            showInMode: ["creating"]
      ]
    @items.push @buttonsContainer
    @callParent()

  updateButtons: (mode) ->
    @buttonsContainer.items.each (btn) ->
      btn.setVisible(Ext.Array.contains(btn.showInMode, mode))

  doUpdate: ->
    Ext.MessageBox.confirm "Delete alerts",
      "Are you sure you wish to delete all alerts for this graph?",
      =>
        @doMuleAction ("PUT")

  doMuleAction: (method) ->
    @submit(
      url: Muleview.Mule.getAlertCommandUrl(Muleview.currentKey, Muleview.currentRetention)
      method: method
      success: ->
        Muleview.Graphs.createGraphs()
      )

  doDelete: ->
    @doMuleAction("DELETE")

  doCreate: ->
    @getForm().clearInvalid()
    @fieldsContainer.show()
    @updateButtons("creating")

  doCancel: ->
    @fieldsContainer.hide()
    @updateButtons("create")