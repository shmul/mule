# Overrides Extjs's native tooltip, making it disappear on mouseover
Ext.define "Muleview.view.ToolTip",
  override: "Ext.tip.ToolTip"
  constructor: (config) ->
    @callParent(arguments)
    @addListener "afterrender", (me) ->
      me.getEl().on
        mousemove: ->
          me.hide()
