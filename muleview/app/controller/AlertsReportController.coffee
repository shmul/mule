Ext.define "Muleview.model.Alert",
  extend: "Ext.data.Model",
  fields: [
      name: "name"
      type: "string"
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
  ]

  set: (attr, value) ->
    @callParent(arguments)
    if attr == "stale" or attr == "period"
      @set("formatted_#{attr}", @formatSeconds(value))
    else if attr == "state"
      # State class is used for icon and background color selection in the grid.
      @set("stateClass", value.replace(/[ _-]/, "-").toLowerCase())


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




Ext.define "Muleview.store.AlertsStore",
  extend: "Ext.data.Store"
  model: "Muleview.model.Alert"
  proxy:
    type: "ajax"
    url: Muleview.Settings.muleUrlPrefix + "/alert"
    reader: Ext.create "Ext.data.reader.Json",
      readRecords: (root) ->
        recordsHash = root.data
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
    @grid.reconfigure Ext.create("Muleview.store.AlertsStore")
    @grid.on
      selectionchange: @clickHandler
      scope: @

    Muleview.app.on
      viewChange: @updateSelection
      alertsChanged: @refresh
      scope: @

      window.setInterval( =>
        @refresh()
      , Muleview.Settings.alertsReportUpdateInterval)
    @refresh()


  updateSelection: (key, retention) ->
    return unless Ext.typeOf(key) == "string" or (Ext.typeOf(key) == "array" and key.length == 1)
    graphName = "#{Ext.Array.from(key)[0]};#{retention}"
    alert = @grid.getStore().findRecord("name", graphName)
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
    @grid.getStore().load()
