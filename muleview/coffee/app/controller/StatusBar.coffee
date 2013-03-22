Ext.define "Muleview.controller.StatusBar",
  extend: "Ext.app.Controller"

  refs: [
      ref: "sb"
      selector: "#statusBar"
    ,
      ref: "lastRefreshLabel"
      selector: "#lastRefreshLabel"
  ]

  onLaunch: ->
    eventsConf = {scope: @}
    eventsConf[eventName] = Ext.bind(handler, @) for own eventName, handler of @handlers
    Muleview.Events.on eventsConf

  progress: (txt) ->
    @status
      iconCls: "x-status-busy"
      text: txt

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

    @getSb().setStatus conf

  timeFormat: (timestamp) ->
    Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.statusTimeFormat)

  updateLastRefresh: ->
    timeStr = Ext.Date.format(new Date(), Muleview.Settings.statusTimeFormat)
    @getLastRefreshLabel().setText("Last updated: #{timeStr}")

  handlers:
    commandSent: (command) ->
      @progress "Requested: #{command}"

    commandReceived: (command)->
      @success "Received request: #{command}"

    chartItemMouseOver: (item) ->
      @status @timeFormat(item.storeItem.get("timestamp"))

    graphsCreated: ->
      @updateLastRefresh()