# Main graph panel component
graphContainer = Ext.create "Ext.panel.Panel",
  title: "Muleview"
  region: "center"
  html: 'Hello! Welcome to Ext JS.'


# *** Tree data and components:

Ext.define "KeyModel",
  extend: "Ext.data.Model"
  fields: ["name"]

treeStore = Ext.create "Ext.data.TreeStore",
  model: "KeyModel"
  root:
    name: "Root Key"

treePanel = Ext.create "Ext.tree.Panel",
  region: "west"
  title: "Available Keys"
  width: "20%"
  split: true
  displayField: "name"
  store: treeStore



# Initial method to fill keys
fillKeys = ->
  root = {}
  getMuleKeys (keys) ->
    for key in keys
      arr = key.split(";")[0].split(".")
      node = root
      until arr.length == 0
        current = arr.shift()
        node = (node[current] ||= {})
    fillTree(treeStore.getRootNode(), root)

# Ajax-Calls mule to retrieve the key list
# Calls given callback with the hash as an argument
# Currently uses mockmule.
getMuleKeys = (fn) ->
  Ext.Ajax.request
    url: "mule/keys"
    success: (response) ->
      obj = null
      callback = (param) ->
        obj = param
      eval(response.responseText)
      keys = obj.data
      fn(keys)

# Receives a hierarchy of keys in the form of nested hashes,
# fills the treeview accordingly
fillTree = (parent, keys) ->
  for name, subkeys of keys
    node = Ext.create "KeyModel",
      name: name
    parent.appendChild(node)
    fillTree(node, subkeys)


# Ext Application structure
Ext.application
  name: "Muleview"
  launch: ->
    Ext.create "Ext.container.Viewport", {
      layout: "border"
      items: [
        treePanel
        graphContainer
      ]
    }
    fillKeys()
