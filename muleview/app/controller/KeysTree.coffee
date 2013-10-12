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

  onLaunch: ->
    @tree = @getTree()
    @store = @tree.getStore()

    @tree.on
      selectionchange: @handleSelectionChange
      itemexpand: @onItemExpand
      itemclick: @handleItemClick
      checkchange: @handleCheckChange
      scope: @

    @getNormalModeBtn().on
      click: => @setMultiMode(false)

    @getMultiModeBtn().on
      click: => @setMultiMode(true)


    Muleview.app.on
      viewChange: @receiveViewChangeEvent
      keysReceived: @addKeys
      scope: @

    @fillFirstkeys()

  # ================================================================
  # Helpers:

  forAllNodes: (fn) ->
    @store.getRootNode().cascadeBy fn

  getSelectedNode: () ->
    @getTree().getSelectionModel().getSelection()[0]

  # ================================================================
  # Event handling:

  setMultiMode: (multi) ->
    return if !!multi == @isMulti
    @isMulti = !!multi

    # Find current selection
    selectedNode = @getSelectedNode()

    @forAllNodes (node) ->
      checked = if multi then (node == selectedNode) else null
      node.set("checked", checked)

    @getMultiModeBtn().setVisible(!multi)
    @getNormalModeBtn().setVisible(multi)

  handleItemClick: (me, node) ->
    # Reverse the check flag if in multi-mode:
    if @isMulti
      node.set("checked", !node.get("checked"))
      @createViewChangeEvent()

  handleCheckChange: ->
    @createViewChangeEvent() if @isMulti

  handleSelectionChange: ->
    @createViewChangeEvent() unless @isMulti

  createViewChangeEvent: ->
    chosenKeys = []
    if @isMulti
      # keys are chosen by their checked value:
      chosenKeys = (node.get("fullname") for node in @getTree().getChecked())
    else
      # the chosen key is the selected key (no, really)
      chosenKeys = @getSelectedNode().get("fullname")

    Muleview.event "viewChange", chosenKeys , Muleview.currentRetention

  receiveViewChangeEvent: (keys) ->
    keysArr = Ext.Array.from(keys)

    # First, we add all the keys for the current view;
    # We optimistically assume every node is a parent; the truth will eventually be revealed since we expand each key,
    # causing @onItemExpand() to reveal its true status
    keysHash = {}
    keysHash[key] = true for key in keysArr
    @addKeys(keysHash)

    @setMultiMode(@isMulti or keysArr.length > 1)

    if @isMulti
      @tree.getSelectionModel().deselectAll()
      @forAllNodes (node) =>
        checked = Ext.Array.contains(keysArr, node.get("fullname"))
        node.set("checked", checked)
        @expandKey(node) if checked

    else
      chosenNode = @store.getById(keysArr[0])
      if chosenNode
        @tree.getSelectionModel().select(chosenNode, false, true) # Don't keep existing selection, suppress events
        @expandKey(chosenNode)

  onItemExpand: (node) ->
    # We set the node as "loading" to reflect that an asynch request is being sent to request deeper-level keys
    node.set("loading", true)
    @fetchKeys node.get("fullname"), (keys) =>
      # Mark the original node as done loading:
      node.set("loading", false)

  # ================================================================
  # Data fetching and displaying:

  fillFirstkeys: ->
    # Add Root key:
    root = @getMuleKeyModel().create
      name: "root"
      fullname: "_root"
    @store.setRootNode(root)

    # Ask Mule for the first keys
    @getTree().setLoading(true)
    @fetchKeys "", =>
      @getTree().setLoading(false)

  fetchKeys: (parent, callback) ->
    Muleview.Mule.getSubKeys parent, 1, (keys) =>
      @addKeys keys
      callback?(keys)

  addKeys: (newKeys) ->
    @addKey(key, hasKids) for key, hasKids of newKeys
    @store.sort ["name"]

  addKey: (key, hasKids) ->
    # Don't add already existing keys:
    return @store.getRootNode() unless key
    existingNode = @store.getById(key)
    if existingNode
      existingNode.set("leaf", !hasKids)
      return existingNode

    # Make sure the parent exists:
    parentName = key.substring(0, key.lastIndexOf("."))
    parent = @addKey(parentName, true)

    # Create the new node:
    newNode = @getMuleKeyModel().create
      name: key.substring(key.lastIndexOf(".") + 1)
      leaf: !hasKids
      checked: if @isMulti then false else undefined
      fullname: key

    # Add the new node as a child to its parent:
    parent.appendChild(newNode)

    # Return the new node:
    return newNode

  # expand a tree item and all its ancestors:
  expandKey: (record) ->
    if (record)
      record.expand()
      @expandKey(record.parentNode)
