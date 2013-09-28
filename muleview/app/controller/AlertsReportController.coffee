# === Model =====================================================
Ext.define "Muleview.model.Alert",
  extend: "Ext.data.Model",
  idProperty: "name"
  fields: [
      name: "name"
      type: "string"
    ,
      name: "isOn" # Not really persistent - used only by AlertsEditor
      type: "boolean"
      defaultValue: true
    ,
      name: "critical_low"
      type: "int"
    ,
      name: "warning_low"
      type: "int"
    ,
      name: "warning_high"
      type: "int"
    ,
      name: "critical_high"
      type: "int"
    ,
      name: "period"
      type: "string"
    ,
      name: "stale"
      type: "string"
    ,
      name: "sum",
      type: "int"
    ,
      name: "state"
      type: "string"
    ,
      name: "formatted_period"
      type: "string"
    ,
      name: "formatted_stale"
      type: "string"
    ,
      name: "stateClass"
      type: "string"
    ,
      name: "severity"
      type: "string"
  ]

  severityClasses:
    "CRITICAL HIGH": "Critical"
    "CRITICAL LOW": "Critical"
    "WARNING HIGH": "Warning"
    "WARNING LOW": "Warning"
    "STALE": "Stale"
    "NORMAL": "Normal"

  set: (attr, value) ->
    @callParent(arguments)
    if attr == "stale" or attr == "period"
      @set("formatted_#{attr}", @formatSeconds(value))
    else if attr == "state"
      # State class is used for icon and background color selection in the grid.
      @set("stateClass", value.replace(/[ _-]/, "-").toLowerCase())
      @set("severityClass", @severityClasses[value.toUpperCase()])

  formatSeconds: (secs) ->
    deviders = [
      ["Year",  60 * 60 * 24 * 365]
      ["Day",  60 * 60 * 24]
      ["Hour",  60 * 60]
      ["Minute",  60]
      ["Second",  1]
    ]
    ans = []
    for [devider, size], i in deviders
      if secs >= size
        remainder = secs % size
        subtract = (secs - remainder) / size
        secs = remainder
        ans.push(if remainder == 0 then " and " else ", ") if ans.length > 0
        ans.push "#{subtract} #{devider}"
        ans.push "s" if subtract > 1
    ans.join("")

  alertComponents: [
      name: "critical_high"
      label: "Critical High"
      color: "red"
    ,
      name: "warning_high"
      label: "Warning High"
      color: "orange"
    ,
      name: "warning_low"
      label: "Warning Low"
      color: "orange"
    ,
      name: "critical_low"
      label: "Critical Low"
      color: "red"
  ]

  toGraphArray: () ->
    for cmp in @alertComponents
      Ext.apply({value: @get(cmp.name)}, cmp)

# ==== Store =====================================================
Ext.define "Muleview.store.AlertsStore",
  extend: "Ext.data.Store"
  id: "alertsStore"
  model: "Muleview.model.Alert"
  proxy:
    type: "ajax"
    url: Muleview.Settings.muleUrlPrefix + "alert"
    reader: Ext.create "Ext.data.reader.Json",
      readRecords: (root) ->
        records = []

        fields = [
          "critical_low"
          "warning_low"
          "warning_high"
          "critical_high"
          "period"
          "stale"
          "sum"
          "state"
        ]

        for key, values of root.data
          record = Ext.create("Muleview.model.Alert")
          record.set(prop, values.shift()) for prop in fields
          record.set("name", key)
          record.commit()
          records.push(record)

        Ext.create "Ext.data.ResultSet",
          total: records.length
          count: records.length
          records: records
          success: true

# === Controller ========================================================

Ext.define "Muleview.controller.AlertsReportController",
  extend: "Ext.app.Controller"
  models: [
    "Muleview.model.Alert"
  ]

  refs: [
    ref: "grid"
    selector: "#alertsReport"
  ]

  onLaunch: ->
    @grid = @getGrid()
    @store = Ext.create("Muleview.store.AlertsStore")
    @store.on
      datachanged: @handleLoad
      scope: @

    @grid.reconfigure @store
    @grid.on
      selectionchange: @clickHandler
      collapse: @handleGridCollapse
      scope: @

    Muleview.app.on
      viewChange: @updateSelection
      alertsChanged: @refresh
      scope: @

      window.setInterval( =>
        @refresh()
      , Muleview.Settings.alertsReportUpdateInterval)
    @refresh()

    # Register alerts summary buttons click handlers:
    @alertSummaryButtons = (Ext.getCmp("alertsSummary#{severity}") for severity in ["Total", "Critical", "Warning", "Normal", "Stale"])
    for button in @alertSummaryButtons
      button.on "click", @alertsSummaryButtonClick, @

  handleGridCollapse: ->
    for button in @alertSummaryButtons
      button.toggle false

  alertsSummaryButtonClick: (el, e) ->
    selectedState = null
    @store.clearFilter()
    for button in @alertSummaryButtons
      if button.pressed
        selectedState = button.alertState
    if selectedState == null
      @grid.collapse()
    else
      @store.filter("stateClass", new RegExp(selectedState, "i")) if selectedState != "total"
      @grid.expand()

  handleLoad: (store) ->
    summary = {
      Critical: 0
      Warning: 0
      Normal: 0
      Stale: 0
    }

    store.each (record) ->
      severity = record.get("severityClass")
      summary[severity] += 1

    for severity, value of summary
      Ext.getCmp("alertsSummary#{severity}").setText("#{severity}: #{value}")
    Ext.getCmp("alertsSummaryTotal").setText("Total: #{store.getCount()}")

  updateSelection: (key, retention) ->
    return unless Ext.typeOf(key) == "string" or (Ext.typeOf(key) == "array" and key.length == 1)
    graphName = "#{Ext.Array.from(key)[0]};#{retention}"
    alert = @grid.getStore().getById(graphName)
    selModel = @grid.getSelectionModel()
    if alert
       selModel.select(alert, false, false)
    else
      selModel.deselectAll()

  clickHandler: (me, selection) =>
    return if Ext.isEmpty(selection)
    [key, retention]  = selection[0].get("name").split(";")
    Muleview.event "viewChange", key, retention

  refresh: ->
    @store.load()
