Ext.define "Muleview.controller.StatusBar",
  extend: "Ext.app.Controller"

  refs: [
      ref: "sb"
      selector: "#statusBar"
    ,
      ref: "lastRefreshLabel"
      selector: "#lastRefreshLabel"
    ,
      ref: "statusLabel"
      selector: "#statusLabel"
    ,
      ref: "alertsReport"
      selector: "#alertsReport"
  ]

  onLaunch: ->
    eventsConf = {scope: @}
    eventsConf[eventName] = Ext.bind(handler, @) for own eventName, handler of @handlers
    Muleview.app.on eventsConf
    for severity in ["Critical", "Warning", "Normal", "Stale"]
      Ext.getCmp("alertsSummary#{severity}").on("click", @openAlertsReport, @)

  openAlertsReport: ->
    @getAlertsReport().expand()
  progress: (txt) ->
    @status
      iconCls: "x-status-busy"
      text: txt
      clear: false

  success: (txt) ->
    @status
      iconCls: "x-status-valid"
      text: txt

  status: (conf) ->
    conf = {text: conf} if Ext.isString(conf)
    Ext.applyIf conf,
      iconCls: ""
      clear:
        anim: false
        wait: 3000
        useDefaults: true

    # TODO: fix all old statusdbar code

    @getStatusLabel().setText conf.text
    clearTimeout(@lastTimeout) if @lastTimeout
    @lastTimeout = setTimeout( =>
      @status("Ready.")
    , 3000)


  timeFormat: (timestamp) ->
    Ext.Date.format(Muleview.toUTCDate(new Date(timestamp * 1000)), Muleview.Settings.statusTimeFormat)

  updateLastRefresh: ->
    timeStr = Ext.Date.format(new Date(), Muleview.Settings.statusTimeFormat)
    @getLastRefreshLabel().setText("Last updated: #{timeStr}")

  handlers:
    commandSent: (command) ->
      @progress "Requested: #{command}"

    commandReceived: (command)->
      @success "Received request: #{command}"

    # chartItemMouseOver: (item) ->
    #   @status @timeFormat(item.storeItem.get("timestamp"))

    graphsCreated: ->
      @updateLastRefresh()
