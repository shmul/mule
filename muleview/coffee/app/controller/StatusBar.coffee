Ext.define "Muleview.controller.StatusBar",
  extend: "Ext.app.Controller"

  refs: [
    ref: "sb"
    selector: "#statusBar"
  ]

  onLaunch: ->
    Muleview.Events.on
      commandSent: @commandSent
      commandReceived: @commandReceived
      chartItemMouseOver: @chartItemMouseOver
      scope: @

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

  commandSent: (command) ->
    @progress "Requested: #{command}"

  commandReceived: (command)->
    @success "Information received for: #{command}"

  chartItemMouseOver: (args...) ->
    @status "Item info: #{args}"