Ext.define "Muleview.controller.History",
  requires: [
    "Ext.util.History"
    "Muleview.Events"
  ]

  gotoToken: (token) ->
    Muleview.event "graphRequest", token.split(";")...

  init: ->
  onLaunch: ->
    Ext.onReady =>
      Ext.util.History.init =>
        Ext.util.History.on
          change: @gotoToken
          scope: @
      @gotoToken Ext.util.History.getToken()
