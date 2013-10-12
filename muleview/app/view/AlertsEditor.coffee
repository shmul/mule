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
  width: 440
  bigHeight: 390
  smallHeight: 154
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
          xtype: "muletimefield"
          name: "period"
          fieldLabel: "Alert Period"
        ,
          html: "<hr />"
          border: false
        ,
          xtype: "container"

          layout:
            type: "table"
            columns: 3

            tableAttrs:
              style:
                width: "100%"

            trAttrs:
              style:
                height: "30px"
                "vertical-align": "middle"

          items: [
              xtype: "label"
              cls: "alerts-editor-table-header"
              text: "Alert Type"
            ,
              xtype: "label"
              cls: "alerts-editor-table-header"
              text: "Total Period"

            ,
              xtype: "label"
              cls: "alerts-editor-table-header"
              text: "Average Step"
          ].concat(@createAlertRows())
        ,
          html: "<hr />"
          border: false
        ,
          xtype: "muletimefield"
          name: "stale"
          fieldLabel: "Stale Period"
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
      items: formItems
      listeners:
        validitychange: (me, valid) =>
          this.saveButton.setDisabled(!valid)

    [@form]

  createAlertRows: () ->
    ans = []

    allAlerts = [
      ["Critical", "High"]
      ["Critical", "Low"]
      ["Warning" , "Low"]
      ["Warning" , "High"]
    ]

    for [severity, pos] in allAlerts
      ans = ans.concat(@createAlertRow(severity, pos))
    ans

  createAlertRow: (severityCase, posCase) ->
    severity = severityCase.toLowerCase()
    pos = posCase.toLowerCase()

    label = Ext.create "Ext.form.Label",
      xtype: "label"
      cls: "alerts-editor-row-#{severity}-#{pos}"
      text: "#{severityCase} #{posCase}"

    total = Ext.create "Ext.form.field.Number",
      name: "#{severity}_#{pos}"
      width: 100
      # listeners:
      #   change: =>
      #     @updateAverages


    average = Ext.create "Ext.form.field.Number",
      name: "#{severity}_#{pos}_average"
      fieldLabel: "="
      labelWidth: 10
      labelSeparator: ""
      # listeners:
      #   change: =>
      #     total.setValue(average.getValue() * @conversionRate)

    @alertRows.push([total, average])

    [label, total, average]

  getForm: ->
    @form.getForm()

  load: () ->
    alertName = @key + ";" + @retention
    @alert = Ext.StoreManager.get("alertsStore").getById(alertName)
    @alert ||= @createDefaultAlert()
    @form.loadRecord(@alert)
    @updateConversionRate()
    @formatTimeFields()
    @getForm().clearInvalid()
    @updateHeight(@alert.get("isOn"))

  updateConversionRate: ->
    return unless @getForm().isValid()
    periodStr = @getForm().getValues().period
    periodStr += "s" unless periodStr.match(/[smhdy]/)
    period = Muleview.model.Retention.getMuleTimeValue(periodStr)
    bucket = new Muleview.model.Retention(@retention).getStep()
    @conversionRate = period / bucket
    @updateAverages()

  alertRows: []

  updateAverages: ->
    for [total, average] in @alertRows
      average.setValue total.getValue() / @conversionRate

  formatTimeFields: ->
    for timeField in @form.query("muletimefield")
      value = timeField.getValue()
      timeField.setValue(Muleview.model.Retention.toShortFormat(value)) unless timeField.value.match(/[smhdy]$/)

  createDefaultAlert: () ->
    defaultPeriodCount = 3 # How much bucket-size steps to take for the default period value
    defaultStaleCount = 3 # How much bucket-size steps to take for the default stale value
    criticalOffset = 0.1 # How much to offset from extreme points to take in percentage to calculate critical values

    max = 0
    min = 9007199254740992 # That's quite a lot, isn't it

    # Find min/max values:
    iterations = Math.max(0, (@store.getCount() - defaultPeriodCount - 1))
    for i in [0..iterations]
      sum = 0
      for j in [i..i + defaultPeriodCount]
        sum += @store.getAt(j).get(@key) if j < @store.getCount()
      max = Math.max(max, sum)
      min = Math.min(min, sum)

    step = new Muleview.model.Retention(@retention).getStep()
    stale = step * defaultStaleCount
    period = step * defaultPeriodCount

    Ext.create "Muleview.model.Alert",
      name: @key + ";" + @retention
      warning_low: min
      critical_low: min * (1 - criticalOffset)
      warning_high: max
      critical_high: max * (1 + criticalOffset)
      stale:  step * defaultStaleCount
      period: step * defaultPeriodCount
      isOn: false

  updateHeight: (mode)->
    height = if mode then @bigHeight else @smallHeight
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
          @formatTimeFields()
      ,
        "-"
      ,
        text: "Auto"
        tooltip: "Set values according to currently known graph data"
        flex: 1
        icon: "resources/default/images/wand.png"
        handler: =>
          @adjust()
          @formatTimeFields()
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
        this.saveButton = Ext.create "Ext.button.Button",
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
    @setLoading(true)
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
