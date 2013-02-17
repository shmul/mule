Ext.define "Muleview.store.KeysTreeStore",
  extend:  "Ext.data.TreeStore"
  requires: [
    "Muleview.model.KeyModel"
  ]
  model: "KeyModel"
  root:
    name: "Root Key"
