Ext.define "Muleview.Events",
  singleton: true
  mixins:
    observable: "Ext.util.Observable"

  constructor:  (config) ->
    @mixins.observable.constructor.call(@, config);