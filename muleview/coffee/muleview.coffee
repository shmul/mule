
pullData = () ->
  console.log("muleview.coffee\\ 3: <HERE>")
  fullname = treePanel.getSelectionModel().getSelection()[0]?.get('fullname')
  document.title = fullname
  askMule "graph/" + fullname, (response) ->
    console.log("muleview.coffee\\ 7: response:", response);
    data = []
    chartStore.removeAll()
    for own key, keyData of response
      for [count, batch, timestamp] in keyData
        data.push {
          timestamp: new Date(timestamp * 1000)
          count: count
        }
      console.log("muleview.coffee\\ 15: <HERE>");
      break

    console.log("muleview.coffee\\ 18: data:", data);
    Ext.Array.sort data, (a, b) ->
      a.timestamp - b.timestamp
    console.log("muleview.coffee\\ 19: data:", data);
    chartStore.add(data)
    chartContainer.items.add(createChart())

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


# General method to query mule
askMule = (command, fn) ->
  Ext.Ajax.request
    url: "mule/" + command
    success: (response) ->
      fn(JSON.parse(response.responseText).data)

# Ajax-Calls mule to retrieve the key list
# Calls given callback with the hash as an argument
# Currently uses mockmule.
getMuleKeys = (fn) ->
  askMule("key?deep=true" ,fn)

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

################################################################
# Components:

# DATA COMPONENTS:
# -----------------

# CHART:
Ext.define "MuleRecord"
  extend: "Ext.data.Model"
  fields: [
    {
      name: "timestamp"
      type: "Date"
      # type: "int"
    },
    {
      name: "count"
      type: "int"
    }
  ]

chartStore = Ext.create "Ext.data.Store",
  model: MuleRecord
  sorters: [
    "timestamp"
  ]

# TREE:
Ext.define "KeyModel",
  extend: "Ext.data.Model"
  fields: [
    "name",
    "fullname"
  ]

treeStore = Ext.create "Ext.data.TreeStore",
  model: "KeyModel"
  root:
    name: "Root Key"

# UI COMPONENTS:
# --------------

# Main graph panel component

createChart = ->
  Ext.create "Ext.chart.Chart",
    store: chartStore
    series: [
      {
        type: 'line',
        xField: 'timestamp',
        yField: 'count'
      }
    ]
    axes: [
      {
        title: "When?"
        type: "Time"
        position: "bottom"
        fields: ["timestamp"]
      },

      {
        title: 'Count'
        type: 'Numeric'
        position: 'left'
        fields: ['count']
        minimum: 0
      }
    ]


chartContainer = Ext.create "Ext.panel.Panel",
  title: "Muleview"
  region: "center"
  layout: "fit"
  items: [ ]

treePanel = Ext.create "Ext.tree.Panel",
  region: "west"
  collapsible: true #TODO CHECK
  title: "Available Keys"
  width: "20%"
  split: true
  displayField: "name"
  listeners:
    selectionchange: pullData
  # rootVisible: false
  store: treeStore

# Ext Application structure
Ext.application
  name: "Muleview"
  launch: ->
    Ext.create "Ext.container.Viewport", {
      layout: "border"
      items: [
        treePanel
        chartContainer
      ]
    }
    fillKeys()
