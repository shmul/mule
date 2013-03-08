Ext.define "Muleview.controller.StatusBar",
  extend: "Ext.app.Controller"

  refs: [
    ref: "sb"
    selector: "#statusBar"
  ]

  onLaunch: ->
    conf = {scope: @}
    conf[eventName] = Ext.bind(handler, @) for own eventName, handler of @handlers
    Muleview.Events.on conf

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

  handlers:
    commandSent: (command) ->
      @progress "Requested: #{command}"

    commandReceived: (command)->
      @success "Information received for: #{command}"

    chartItemMouseOver: (item) ->
      @status @timeFormat(item.storeItem.get("timestamp"))