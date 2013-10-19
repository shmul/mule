Ext.define "Muleview.controller.StatusBar",
  extend: "Ext.app.Controller"

  refs: [
      ref: "sb"
      selector: "#statusBar"
    ,
      ref: "statusLabel"
      selector: "#statusLabel"
    ,
      ref: "statusRightLabel"
      selector: "#statusRightLabel"
    ,
      ref: "alertsReport"
      selector: "#alertsReport"
  ]

  onLaunch: ->
    @sbLabel = @getStatusLabel()
    @sbRightLabel = @getStatusRightLabel()
    # Register all handlers:
    Muleview.app.on Ext.merge(@handlers, {scope: @ })

  inProgress: {}

  progress: (txt, progressId) ->
    @inProgress[progressId] = txt
    @status txt, "progress"

  success: (txt, progressId) ->
    delete @inProgress[progressId]
    @status txt, "success"

  failure: (txt, progressId) ->
    Ext.Array.remove(@inProgress, progressId)
    @status "ERROR - " + txt, "error", "ERORR"

  status: (text, iconCls = "normal", logLevel = "INFO") ->
    rightText = ""
    if Ext.typeOf(text) == "object"
      rightText = text.rightText
      text = text.leftText

    # Set current text and icon:
    @sbLabel.setText text
    @sbRightLabel.setText rightText
    @setIcon iconCls

    # Reset clearance method:
    clearTimeout(@lastTimeout) if @lastTimeout
    @lastTimeout = setTimeout( Ext.bind(@resetSb, @) , 3000)

    # Log to console:
    console.log logLevel, new Date(), "(#{iconCls})", text if console and logLevel

  resetSb: ->
    if Ext.isEmpty(@inProgress)
      @status "Ready.", null, false
    else
      firstValue = nil
      Ext.each @inProgress, (key, value) ->
        firstValue = value
        false

      @status firstValue, "progress", false

  setIcon: (clsSuffix) ->
    cls = "statusLabel-" + clsSuffix
    @sbLabel.removeCls(@lastCls) if @lastCls
    @sbLabel.addCls(cls)
    @lastCls = cls

  handlers:
    chartMouseover: (point) ->
      # Value:
      value = point.value.y
      valueText = Ext.util.Format.number(value, ",0")

      if point.series.type == "subkey"
        percent =  point.value.percent
        percentText = Ext.util.Format.number(percent, "0.00")
        valueText += " (#{percentText}%)"

      # Time
      utcOffset = new Date().getTimezoneOffset() * 60
      dateObj = new Date((point.value.x + utcOffset) * 1000)
      date = Ext.Date.format(dateObj, "Y-m-d")
      day = Ext.Date.format(dateObj, "l")
      time = Ext.Date.format(dateObj, "H:i:s")
      timeText = "#{day}, #{date} #{time}"

      @status
        leftText: "#{point.series.name}: #{valueText}"
        rightText: timeText
      , false, false

    commandRetry: (command, attempt) ->
      @status "Command '#{command}' failed. Retrying (#{attempt})...", "error", "ERROR"

    alertsRequest: () ->
      @progress "Requested alert status", "alerts"

    alertsReceived: (eventId) ->
      @success "Updated alerts status", "alerts"

    commandSent: (command, eventId) ->
      @progress "Requested: #{command}", eventId

    commandReceived: (command, eventId, success)->
      if success
        @success "Received request: #{command}", eventId
      else
        @failure "Could not receive request for: #{command}", eventId

    graphsCreated: ->
      @updateLastRefresh()
