graphContainer = Ext.create "Ext.container.Container",
  style:
    background: "red"

# Main graph panel component
mainContainer = Ext.create "Ext.panel.Panel",
  title: "Muleview"
  region: "center"
  layout: "fit"
  items: [ graphContainer ]


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
  # rootVisible: false
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
  url = "http://localhost:3000/key?jsonp=callback"
  window.callback = (response) ->
      keys = response.data
      fn(keys)
  scriptTag = document.createElement("script")
  scriptTag.src=url
  scriptTag.type="text/javascript"
  document.body.appendChild(scriptTag)

# Receives a hierarchy of keys in the form of nested hashes,
# fills the treeview accordingly
fillTree = (parent, keys) ->
  for name, subkeys of keys
    node = Ext.create "KeyModel",
      name: name
    parent.appendChild(node)
    fillTree(node, subkeys)


# graph
testGraph = ->
  data = [ { x: 0, y: 40 }, { x: 1, y: 49 }, { x: 2, y: 17 }, { x: 3, y: 42 } ]
  return
  graph = new Rickshaw.Graph
    element: graphContainer.el.dom
    width: "100%",
    height: "100%",
    series: [
      {
        color: 'steelblue'
        data: data
      }
    ]
  graph.render()



# Ext Application structure
Ext.application
  name: "Muleview"
  launch: ->
    Ext.create "Ext.container.Viewport", {
      layout: "border"
      items: [
        treePanel
        mainContainer
      ]
    }
    fillKeys()
    testGraph()
