Ext.define "Muleview.store.ChartStore",
  extend:  "Ext.data.Store"
  requires: [
    "Muleview.model.MuleRecord"
  ]
  model: MuleRecord
  sorters: [
    "timestamp"
  ]
