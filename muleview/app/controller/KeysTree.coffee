Ext.define "Muleview.controller.KeysTree",
  extend: "Ext.app.Controller"
  models: [
    "MuleKey"
  ]

  multiMode: false

  refs: [
      ref: "tree"
      selector: "#keysTree"
    ,
      ref: "mainPanel"
      selector: "#mainPanel"
    ,
      ref: "normalModeBtn"
      selector: "#btnSwitchToNormal"
    ,
      ref: "multiModeBtn"
      selector: "#btnSwitchToMultiple"
  ]

  onSelectionChange: (me, selected)->
    return unless selected[0]
    if @multiMode
      keys = node.get("fullname") for node in @getTree().getChecked()
    else
      keys = selected[0].get("fullname")
    Muleview.event "viewChange", keys, Muleview.currentRetention

  onLaunch: ->
    @store = @getTree().getStore()

    @getTree().on
      selectionchange: @onSelectionChange
      itemexpand: @onItemExpand
      # checkchange: @onCheckChange
      scope: @

    @getNormalModeBtn().on
      scope: @
      click: -> @setMultiMode(false)

    @getMultiModeBtn().on
      scope: @
      click: -> @setMultiMode(true)


    Muleview.app.on
      viewChange: @updateSelection
      keysReceived: @addKeys
      scope: @

    @fillFirstkeys()

  setMultiMode: (multi) ->
    @multiMode = multi
    @getMultiModeBtn().setVisible(!multi)
    @getNormalModeBtn().setVisible(multi)
    selectedNode = @getTree().getSelectionModel().getSelection()[0]
    @store.getRootNode().cascadeBy (node) ->
      checked = null
      if multi
        checked = node == selectedNode
      node.set("checked", checked)

  onItemExpand: (node) ->
    # We set the node as "loading" to reflect that an asynch request is being sent to request deeper-level keys
    node.set("loading", true)
    @fetchKeys node.get("fullname"), (keys) =>
      # We would like to mark subkeys which we know for sure that they are leaves
      # NOTE: We assume Mule returned at least 2 levels of keys!
      for key in keys
        record = @store.getById(key)
        # Since at least 2 levels of keys were received, if a node in the first level has no children then it is definitely a leaf:
        if record.parentNode == node and not record.firstChild
          record.set("leaf", true)
          record.set("loaded", true)
      # Mark the original node as done loading:
      node.set("loading", false)


  fillFirstkeys: ->
    # Add Root key:
    root = @getMuleKeyModel().create
      name: "root"
      fullname: "_root"
    @store.setRootNode(root)

    # Ask Mule for the first keys
    @fetchKeys("")

  fetchKeys: (parent, callback) ->
    Muleview.Mule.getSubKeys parent, 2, (keys) =>
      @addKeys keys
      callback?(keys)

  addKeys: (newKeys) ->
    @addKey(key) for key in newKeys

  addKey: (key) ->
    # Don't add already existing keys:
    return @store.getRootNode() unless key
    existingNode = @store.getById(key)
    return existingNode if existingNode

    # Make sure the parent exists:
    parentName = key.substring(0, key.lastIndexOf("."))
    parent = @addKey(parentName)

    # Create the new node:
    newNode = @getMuleKeyModel().create
      name: key.substring(key.lastIndexOf(".") + 1)
      fullname: key

    # Add the new node as a child to its parent:
    parent.appendChild(newNode)

    # Return the new node:
    return newNode

  updateSelection: (newKey) ->
    record = @store.getById(newKey)
    @getTree().getSelectionModel().select(record, false, true)
    while record
      record.expand()
      record=record.parentNode
