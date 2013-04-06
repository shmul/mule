Ext.define "Muleview.controller.History",
  extend: "Ext.app.Controller"
  requires: [
    "Ext.util.History"
  ]

  addToken: (key, ret) ->
    return unless key and ret
    Ext.util.History.add key + ";" + ret

  gotoToken: (token) ->
    [key, retention] = (token ? "").split(";")
    Muleview.event "viewChange", key, retention if key

  init: ->

  onLaunch: ->
    Ext.onReady =>
      Ext.util.History.init =>
        Ext.util.History.on
          change: @gotoToken
          scope: @
      @gotoToken Ext.util.History.getToken()
    Muleview.app.on
      scope: @
      viewChange: (key, ret) ->
        @addToken(key, ret)