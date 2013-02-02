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
  fields: ["name", "fullname"]

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
  listeners:
    selectionchange: (me, selected) ->
      updateGraph(selected[0].get("fullname")) if selected?[0]
  # rootVisible: false
  store: treeStore

askMule = (command, fn) ->
  Ext.Ajax.request
    url: "mule/" + command
    success: (response) ->
      fn(JSON.parse(response.responseText).data)

updateGraph = (fullname) ->
  askMule "graph/" + fullname + ".", (response) ->
    graphContainer.html = response

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
  askMule("key" ,fn)
# Receives a hierarchy of keys in the form of nested hashes,
# fills the treeview accordingly
fillTree = (parent, keys) ->
  for name, subkeys of keys
    fullname = ((parent?.get("fullname") && (parent.get("fullname") + ".")) || "") + name
    node = Ext.create "KeyModel",
      name: name
      fullname: fullname
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
