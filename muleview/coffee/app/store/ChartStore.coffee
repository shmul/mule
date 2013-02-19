Ext.define "Muleview.store.ChartStore",
  extend:  "Ext.data.ArrayStore"
  requires: [
    "Muleview.model.MuleRecord"
  ]
  model: "Muleview.model.MuleRecord"
  sorters: [
    "timestamp"
  ]
