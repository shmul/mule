labelFormat = "d/m/y H:i:s"

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
          timestamp: timestamp
          count: count
        }
      console.log("muleview.coffee\\ 15: <HERE>");
      break

    console.log("muleview.coffee\\ 18: data:", data);
    Ext.Array.sort data, (a, b) ->
      a.timestamp - b.timestamp
    for record in data
      console.log record.timestamp
    console.log("muleview.coffee\\ 19: data:", data);
    chartStore.add(data)
    chartContainer.items.add(createChart())
    setTimeout ->
      chartContainer.doLayout()
    , 1


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