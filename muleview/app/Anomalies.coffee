Ext.define "Muleview.Anomalies",
  singleton: true

  anomalies: {}

  updateAnomalies: (data) ->
    @anomalies = data
    Muleview.event "anomaliesupdate"

  getAnomaliesForKey: (key) ->
    @anomalies[key] || []
