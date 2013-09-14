Ext.define "Muleview.controller.History",
  extend: "Ext.app.Controller"
  requires: [
    "Ext.util.History"
  ]

  addToken: (keys, ret) ->
    return unless keys and ret
    Ext.util.History.add Ext.Array.from(keys).join(",") + ";" + ret

  gotoToken: (token) ->
    [keys, retention] = (token ? "").split(";")
    keys = keys.split(",")
    Muleview.event "viewChange", keys, retention if keys.length > 0 and keys[0].length > 0

  onLaunch: ->
    Ext.onReady =>
      Ext.util.History.init =>
        Ext.util.History.on
          change: @gotoToken
          scope: @
      @gotoToken Ext.util.History.getToken()
    Muleview.app.on
      scope: @
      viewChange: (keys, ret) ->
        @addToken(keys, ret)
