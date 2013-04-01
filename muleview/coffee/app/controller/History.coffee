Ext.define "Muleview.controller.History",
  extend: "Ext.app.Controller"
  requires: [
    "Ext.util.History"
    "Muleview.Events"
  ]

  gotoToken: (token) ->
    [key, retention] = (token ? "").split(";")
    Muleview.event "graphRequest", key, retention if key

  init: ->
  onLaunch: ->
    Ext.onReady =>
      Ext.util.History.init =>
        Ext.util.History.on
          change: @gotoToken
          scope: @
      @gotoToken Ext.util.History.getToken()
