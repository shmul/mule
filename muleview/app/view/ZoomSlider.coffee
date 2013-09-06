Ext.define "Muleview.view.ZoomSlider",
  extend: "Ext.slider.Multi"

  tipText: (thumb) ->
    new Date(thumb.value * 1000).toUTCString()

  changeHandler: () ->
    [@minDate, @maxDate] = @getValues()
    @store.filterBy (record) =>
      @minDate <= record.get("timestamp") <= @maxDate

  initComponent: ->
    # init slider's values according to given store:
    @maxValue = @store.max("timestamp")
    @minValue = @store.min("timestamp")
    @increment = (@maxValue - @minValue) / 100
    @values = [@minValue, @maxValue]

    # Register change handler:
    @addListener "change", Ext.Function.createBuffered(@changeHandler, 100)

    # I'm ready:
    @callParent()
