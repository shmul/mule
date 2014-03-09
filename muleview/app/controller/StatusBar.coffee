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
    ,
      ref: "pbar"
      selector: "#statusProgressbar"
    ,
      ref: "stats"
      selector: "#statusStats"
  ]

  onLaunch: ->
    @sbLabel = @getStatusLabel()
    @pbar = @getPbar();
    # Register all handlers:
    Muleview.app.on Ext.merge(@handlers, {scope: @ })

  inProgressMax: 0
  inProgress: {}

  progress: (txt, progressId) ->
    @inProgressMax += 1
    @inProgress[progressId] = txt
    @status txt, "progress"

  success: (txt, progressId) ->
    delete @inProgress[progressId]
    @status txt, "success"

  failure: (txt, progressId) ->
    delete @inProgress[progressId]
    @status "ERROR - " + txt, "error", "ERORR"

  status: (text, iconCls = "normal", logLevel = "INFO") ->
    # Update Progress bar:
    if @inProgressMax > 0
      do () =>
        total = @inProgressMax
        done = total - Ext.Object.getKeys(@inProgress).length
        val = (done / total)
        @pbar.updateProgress(val, Math.round(val * 100) + "%")
        @pbar.show()

    # Set current text and icon:
    @sbLabel.setText text
    @setIcon iconCls

    # Reset clearance method:
    clearTimeout(@lastTimeout) if @lastTimeout
    @lastTimeout = setTimeout( Ext.bind(@resetSb, @) , 3000)
    if @noRequestsPending()
      Ext.defer =>
        if @noRequestsPending()
          @inProgressMax = 0
          @pbar.hide()
          @pbar.updateProgress(0)
      , 2000


    # Log to console:
    console?.log? logLevel, new Date(), "(#{iconCls})", text if logLevel

  noRequestsPending: ->
    Ext.Object.isEmpty(@inProgress)

  resetSb: ->
    Ext.defer( () =>
      if @noRequestsPending()
        @status "Ready.", null, false
      else
        firstValue = Ext.Object.getValues(@inProgress)[0]
        @status firstValue, "progress", false
    , 1000)


  setIcon: (clsSuffix) ->
    cls = "statusLabel-" + clsSuffix
    @sbLabel.removeCls(@lastCls) if @lastCls
    @sbLabel.addCls(cls)
    @lastCls = cls

  handlers:

    statsChange: (stats) ->
      stats.average = Ext.util.Format.number(stats.average, "0.00")
      for stat in ["min", "max", "last"]
        stats[stat] = Ext.util.Format.number(stats[stat], "0,000")
      @getStats().update(stats)

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

      @status "#{timeText} #{point.series.name}: #{valueText}" , null, false

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
