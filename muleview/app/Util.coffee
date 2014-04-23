Ext.define "Muleview.Util",
  singleton: true
  asyncProcess: (opts = {}) ->
    array = opts.array
    processFn = opts.processFn
    finalFn = opts.finalFn || Ext.emptyFn
    step = opts.step || Muleview.Settings.asyncProcessStep || 10

    throw "Invalid Array: #{array}" unless Ext.typeOf(array) == "array"

    fn = () ->
      for i in [0..step] by 1
        if Ext.isEmpty(array)
          finalFn()
          return
        nextItem = array.pop()
        processFn(nextItem)
      Ext.defer(fn, 10)
    fn()
