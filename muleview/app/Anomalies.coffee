Ext.define "Muleview.model.Anomaly",
  extend: "Ext.data.Model"
  idProperty: "name"
  fields: [
      name: "name"
      type: "string"
    ,
      name: "key"
      type: "string"
    ,
      name: "retention"
      type: "string"
    ,
      name: "anomaliesCount"
      type: "int"
    ,
      name: "timestamps"
  ]

Ext.define "Muleview.Anomalies",
  singleton: true

  keysWithAnomalies: {}

  # store: Ext.create "Muleview.store.AnomaliesStore",

  getStore: ->
    unless @store
      @store = Ext.create "Ext.data.ArrayStore",
        model: "Muleview.model.Anomaly",
        data: []
    @store

  updateAnomalies: (data) ->
    @keysWithAnomalies = {}
    records = []
    @data = data
    for name, timestamps of @data
      [key, retention] = name.split(";")
      @keysWithAnomalies[key] = true
      records.push
        name: name
        timestamps: timestamps
        key: key
        retention: retention
        anomaliesCount: timestamps.length

    @getStore().removeAll()
    @getStore().add(records)
    Muleview.event "anomaliesupdate"

  keyHasAnomalies: (key) ->
    @keysWithAnomalies[key]

  getAllKeysWithAnomalies: () ->
    Ext.Object.getKeys(@keysWithAnomalies)

  getAnomaliesForGraph: (key, retention) ->
    record = @getStore().getById("#{key};#{retention}")
    record && record.get("timestamps") || []
