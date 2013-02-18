Ext.define "Muleview.store.ChartStore",
  extend:  "Ext.data.ArrayStore"
  requires: [
    "Muleview.model.MuleRecord"
  ]
  model: "MuleRecord"
  sorters: [
    "timestamp"
  ]
