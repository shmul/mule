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
      @set("formatted_#{attr}", Muleview.model.Retention.toLongFormat(value))
    else if attr == "state"
      # State class is used for icon and background color selection in the grid.
      @set("stateClass", value.replace(/[ _-]/, "-").toLowerCase())
      @set("severityClass", @severityClasses[value.toUpperCase()])

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

  toGraphArray: (retentionName) ->
    ret = new Muleview.model.Retention(retentionName)
    devider = @get("period") / ret.getStep()
    for cmp in @alertComponents
      Ext.apply({value: @get(cmp.name) / devider}, cmp)

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
          if key == "anomalies"
            Muleview.Anomalies.updateAnomalies(values)
          else
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
    ,
      ref: "refreshButton"
      selector: "#alertsSummaryRefresh"
  ]

  onLaunch: ->
    # Init stores:
    @grid = @getGrid()
    @store = Ext.create "Muleview.store.AlertsStore"
    @gridStore = Ext.create "Ext.data.ArrayStore",
      model: "Muleview.model.Alert"
    @grid.reconfigure @gridStore

    # Set refresh interval:
    window.setInterval( =>
      @refresh()
    , Muleview.Settings.alertsReportUpdateInterval)

    # Hook events:

    @store.on
      datachanged: @handleLoad
      load: -> Muleview.event "alertsReceived"
      scope: @

    @grid.on
      selectionchange: @clickHandler
      collapse: @handleGridCollapse
      scope: @

    Muleview.app.on
      viewChange: @updateSelection
      alertsChanged: @refresh
      scope: @

    # Initial load:
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
    @gridStore.clearFilter()
    for button in @alertSummaryButtons
      if button.pressed
        selectedState = button.alertState
    if selectedState == null
      @grid.collapse()
    else
      @gridStore.filter("stateClass", new RegExp(selectedState, "i")) if selectedState != "total"
      @grid.expand()

  handleLoad: (store) ->
    records = []
    summary = {
      Critical: 0
      Warning: 0
      Normal: 0
      Stale: 0
    }

    store.each (record) ->
      records.push(record)
      severity = record.get("severityClass")
      summary[severity] += 1

    for severity, value of summary
      Ext.getCmp("alertsSummary#{severity}").setText("#{severity}: #{value}")
    Ext.getCmp("alertsSummaryTotal").setText("Total Alerts: #{store.getCount()}")
    @gridStore.loadData(records)
    @getRefreshButton().setDisabled(false)
    @getRefreshButton().setIcon("resources/default/images/refresh.png")

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
    @getRefreshButton().setProgress(true)
    Muleview.event "alertsRequest"
    @store.load
      scope: @
      callback: ->
        @getRefreshButton().setProgress(false)
