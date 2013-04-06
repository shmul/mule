Ext.define "Muleview.model.MuleKey",
  extend: "Ext.data.Model"
  idProperty: "fullname"
  requires: [
    "Ext.data.NodeInterface"
  ]

  fields: [
    "name"
    "fullname"
  ]
  listeners:
    append: (me, node) ->
      # Set full name according to path
      fullname = node.getPath("name", ".").substring(".root.".length)
      node.set("fullname", fullname)
, ->
  Ext.data.NodeInterface.decorate this