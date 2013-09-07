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
      selectionchange: @createViewChangeEvent
      itemexpand: @onItemExpand
      checkchange: @createViewChangeEvent
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
    console.log("SETMULTIMODE: ", multi)
    return if !!multi == @isMulti
    @isMulti = !!multi

    # Find current selection
    selectedNode = @getSelectedNode()

    @store.suspendEvents(false) #TODO: check

    @forAllNodes (node) ->
      checked = if multi then (node == selectedNode) else null
      node.suspendEvents(false) #TODO: check
      node.set("checked", checked)
      node.resumeEvents(true) #TODO: check

    @store.resumeEvents() #TODO: check

    @getMultiModeBtn().setVisible(!multi)
    @getNormalModeBtn().setVisible(multi)

  createViewChangeEvent: ->
    console.log("CREATE VIEW CHANGE")
    chosenKeys = []
    if @isMulti
      # keys are chosen by their checked value:
      chosenKeys = (node.get("fullname") for node in @getTree().getChecked())
    else
      # the chosen key is the selected key (no, really)
      chosenKeys = @getSelectedNode().get("fullname")
    Muleview.event "viewChange", chosenKeys , Muleview.currentRetention

  receiveViewChangeEvent: (keys) ->
    console.log("RECEIVE VIEW CHANGE EVENT - ", keys)
    keysArr = Ext.Array.from(keys)
    @setMultiMode(@isMulti or keysArr.length > 1)

    @store.suspendEvents(false) #TODO: check
    @tree.suspendEvents(false) #TODO: check

    if @isMulti
      @tree.getSelectionModel().deselectAll()
      @forAllNodes (node) =>
        checked = Ext.Array.contains(keysArr, node.get("fullname"))
        node.suspendEvents(false) #TODO: check
        node.set("checked", checked)
        node.resumeEvents() #TODO: check

    else
      chosenNode = @store.getById(keysArr[0])
      @tree.getSelectionModel().select(chosenNode)

    @store.resumeEvents() #TODO: check
    @tree.resumeEvents() #TODO: check

  # ================================================================
  # Data fetching and displaying:

  onItemExpand: (node) ->
    # We set the node as "loading" to reflect that an asynch request is being sent to request deeper-level keys
    node.set("loading", true)
    @fetchKeys node.get("fullname"), (keys) =>

      #TODO: implement numchild
      # Commented out the following section after reducing subkey prefetching from 2 to 1 due to apparent overload in key data: <<< BEGIN COMMENTING OUT



      # We would like to mark subkeys which we know for sure that they are leaves
      # NOTE: We assume Mule returned at least 2 levels of keys!
      # for key in keys
      #   record = @store.getById(key)
      #   # Since at least 2 levels of keys were received, if a node in the first level has no children then it is definitely a leaf:
      #   if record.parentNode == node and not record.firstChild
      #     record.set("leaf", true)
      #     record.set("loaded", true)

      # END COMMENTING OUT  >>>
      # Mark the original node as done loading:
      node.set("loading", false)


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

  # expand a tree item and all its ancestors:
  expandKey: (record) ->
    if (record)
      record.expand()
      @expandKey(record.parentNode)
