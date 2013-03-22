Ext.define "Muleview.controller.KeysTree",
  extend: "Ext.app.Controller",
  requires: [
    "Muleview.Events"
  ]
  models: [
    "MuleKey"
  ]
  refs: [
      ref: "tree"
      selector: "#keysTree"
    ,
      ref: "mainPanel"
      selector: "#mainPanel"
  ]

  onSelectionChange: (me, selected)->
    return unless selected[0]
    key = selected[0].get("fullname")
    Muleview.event "graphRequest", key, Muleview.currentRetention

  onLaunch: ->
    @store = @getTree().getStore()

    @getTree().on
      selectionchange: @onSelectionChange
      beforeitemexpand: @onItemExpand
      scope: @

    Muleview.Events.on
      graphChanged: @updateSelection
      keysReceived: @addKeys
      scope: @
    @fillFirstkeys()

  onItemExpand: (node) ->
    @fetchKeys node.get("fullname")

  fillFirstkeys: ->
    # Add Root key:
    root = @getMuleKeyModel().create
      name: "root"
      fullname: "_root"
    @store.setRootNode(root)

    # Ask Mule for the first keys
    @fetchKeys("")

  fetchKeys: (parent) ->
    Muleview.Mule.getSubKeys parent, 1, Ext.bind(@addKeys, @)

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
