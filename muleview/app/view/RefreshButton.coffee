Ext.define "Muleview.view.RefreshButton",
  extend: "Ext.button.Button"
  alias: "widget.muleRefreshButton"

  initComponent: ->
    @on
      boxready: =>
        @setProgress(false)
    @callParent()

  setProgress: (progress) ->
    if progress
      @setIcon("resources/default/images/loading.gif")
      @setDisabled(true)

    else
      @setIcon("resources/default/images/refresh.png")
      @setDisabled(false)
