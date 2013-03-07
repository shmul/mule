Ext.define "Muleview.view.ZoomSlider",
  extend: "Ext.slider.Multi",
  flex: 1
  tipText: (thumb) ->
    new Date(thumb.value * 1000)
  listeners:
    change: Ext.Function.createBuffered (me, newValue) =>
      [min, max] = me.getValues()
      me.store.filterBy (record)->
        min <= record.get("timestamp") <= max
    , 100
  initComponent: ->
    @maxValue = @store.max("timestamp")
    @minValue = @store.min("timestamp")
    @increment = (@maxValue - @minValue) / 100
    @values = [@minValue, @maxValue]
    @callParent()