Ext.define "Muleview.controller.StatusBar",
  extend: "Ext.app.Controller"

  refs: [
      ref: "sb"
      selector: "#statusBar"
    ,
      ref: "statusLabel"
      selector: "#statusLabel"
    ,
      ref: "alertsReport"
      selector: "#alertsReport"
  ]

  onLaunch: ->
    @sbLabel = @getStatusLabel()
    # Register all handlers:
    Muleview.app.on Ext.merge(@handlers, {scope: @ })

  inProgress: []

  progress: (txt, progressId) ->
    @inProgress.push(progressId)
    @status txt, "progress"

  success: (txt, progressId) ->
    Ext.Array.remove(@inProgress, progressId)
    @status txt, "success"

  failure: (txt, progressId) ->
    Ext.Array.remove(@inProgress, progressId)
    @status "ERROR - " + txt, "error"

  status: (text, iconCls = "normal") ->
    # Set current text and icon:
    @sbLabel.setText text
    @setIcon iconCls

    # Reset clearance method:
    clearTimeout(@lastTimeout) if @lastTimeout
    @lastTimeout = setTimeout( Ext.bind(@resetSb, @) , 3000)

  resetSb: ->
    if Ext.isEmpty(@inProgress)
      @status "Ready."
    else
      @status "Pending..", "progress"

  setIcon: (clsSuffix) ->
    cls = "statusLabel-" + clsSuffix
    @sbLabel.removeCls(@lastCls) if @lastCls
    @sbLabel.addCls(cls)
    @lastCls = cls

  handlers:
    commandSent: (command, eventId) ->
      @progress "Requested: #{command}", eventId

    commandReceived: (command, eventId, success)->
      if success
        @success "Received request: #{command}", eventId
      else
        @failure "Could not receive request for: #{command}", eventId

    graphsCreated: ->
      @updateLastRefresh()
