Ext.define "Muleview.controller.KeysTree",
  extend: "Ext.app.Controller",
  models: [
    "MuleKey"
  ]
  refs: [
    {
      ref: "tree"
      selector: "#keysTree"
    }
  ]

  onSelectionChange: (me, selected)->
    return unless selected[0]
    key = selected[0].get("fullname")
    document.title = key
    Muleview.currentKey = key
    Muleview.Graphs.createGraphs()

  onLaunch: ->
    @store = @getTree().getStore()
    @control
      "#keysTree":
        selectionchange: @onSelectionChange


    @fillAllKeys()

  fillAllKeys: ->
    Muleview.Mule.getAllKeys (keys) =>
      root = @getMuleKeyModel().create
        name: "root"
      @store.setRootNode(root)

      for own childName, grandchildren of keys
        @addKey(root, childName, grandchildren)

      # Select first node:
      @getTree().getSelectionModel().select(root.getChildAt(0))
  addKey: (parentNode, name, children) ->
    # Create the node key node:
    newNode = @getMuleKeyModel().create
      name: name

    # Add this node to the parent
    parentNode.appendChild(newNode)

    # Iterate child nodes:
    for own childName, grandchildren of children
      @addKey(newNode, childName, grandchildren)
