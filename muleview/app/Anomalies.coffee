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
      name: "timestamps"
    ,
      name: "latestTimestamp"
      type: "date"
  ]

Ext.define "Muleview.Anomalies",
  singleton: true

  keysWithAnomalies: {}

  getStore: ->
    unless @store
      @store = Ext.create "Ext.data.ArrayStore",
        model: "Muleview.model.Anomaly",
        data: []
        sorters: [
          {
            property: "latestTimestamp"
            direction: "DESC"
          }
        ]
    @store

  getLatestTimestamp: (timestamps) ->
    latestTimestamp = timestamps[0] || 0
    for timestamp in timestamps
      latestTimestamp = Math.max(latestTimestamp, timestamp)
    Muleview.muleTimestampToDate(latestTimestamp)

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
        latestTimestamp: @getLatestTimestamp(timestamps)
        key: key
        retention: retention

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
