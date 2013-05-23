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

  updateSelectedKey: ->

    # Selection doesn't apply rendering in multiMode;
    return if @multiMode

    # Get current selection:
    selection = @getTree().getSelectionModel().getSelection()
    selected = selection[0]

    # Quit if nothing selected:
    return unless selected

    # update:
    key = selected.get("fullname")
    Muleview.event "viewChange", key, Muleview.currentRetention

  onCheckChange: ->
    # return if @updating
    keys = (node.get("fullname") for node in @getTree().getChecked()).join(",")
    Muleview.event "viewChange", keys, Muleview.currentRetention

  onLaunch: ->
    @store = @getTree().getStore()

    @getTree().on
      selectionchange: @updateSelectedKey
      itemexpand: @onItemExpand
      checkchange: @onCheckChange
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
    # Don't change to existing mode:
    return if !!multi == @multiMode

    # Save current state:
    @multiMode = !!multi

    # Update buttons:
    @getMultiModeBtn().setVisible(!multi)
    @getNormalModeBtn().setVisible(multi)

    # Find current selection
    selectedNode = @getTree().getSelectionModel().getSelection()[0]

    # Mark all nodes as unchecked, except for the current selected one:
    @store.getRootNode().cascadeBy (node) ->
      checked = if multi then (node == selectedNode) else null
      node.set("checked", checked)

    # If switching back to single, update the graph:
    @updateSelectedKey() if not multi

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

  updateSelection: (newKeys) ->
    # return if @updating
    # @updating = true
    keysArr = Ext.Array.from(newKeys)
    # @setMultiMode(keysArr.length > 1)
    if keysArr.length == 1
      record = @store.getById(keysArr[0])
      @getTree().getSelectionModel().select(record, false, true)
      while record
        record.expand()
        record=record.parentNode
    # else if keysArr.length > 1
    #   for key in keysArr
    #     record = @store.getById(key)
    #     record?.set("checked", true)
    #     while record
    #       record.expand()
    #       record=record.parentNode
    # @updating = false
