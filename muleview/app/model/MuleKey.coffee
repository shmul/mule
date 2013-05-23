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

      # We do not support "," or ";" in a key name:
      throw "Invalid key name: '#{fullname}'" if /[,;]/.test(fullname)

      node.set("fullname", fullname)
, ->
  Ext.data.NodeInterface.decorate this
