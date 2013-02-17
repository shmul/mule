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

  init: ->
    @control
      "#keysTree":
        selectionchange: @onSelectionChange

  onSelectionChange: (me, selected)->
    document.title = selected[0]?.get("fullname")
    #TODO: reload data

  onLaunch: ->
    @store = @getTree().getStore()


    @fillAllKeys()

  fillAllKeys: ->
    Muleview.Mule.getAllKeys (keys) =>
      root = @getMuleKeyModel().create
        name: "root"
      @store.setRootNode(root)

      for own childName, grandchildren of keys
        @addKey(root, childName, grandchildren)

  addKey: (parentNode, name, children) ->
    # Create the node key node:
    newNode = @getMuleKeyModel().create
      name: name

    # Add this node to the parent
    parentNode.appendChild(newNode)

    # Iterate child nodes:
    for own childName, grandchildren of children
      @addKey(newNode, childName, grandchildren)
