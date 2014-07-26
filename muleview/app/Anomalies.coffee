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

  # store: Ext.create "Muleview.store.AnomaliesStore",

  getStore: ->
    unless @store
      @store = Ext.create "Ext.data.ArrayStore",
        model: "Muleview.model.Anomaly",
        data: []
    @store

  updateAnomalies: (data) ->
    records = []
    for name, timestamps of data
      [key, retention] = name.split(";")
      records.push
        name: name
        timestamps: timestamps
        key: key
        retention: retention
        anomaliesCount: timestamps.length

    @getStore().add(records)
    Muleview.event "anomaliesupdate"

  getAnomaliesForKey: (key, retention) ->
    record = @getStore().getById("#{key};#{retention}")
    record && record.get("timestamps") || []
