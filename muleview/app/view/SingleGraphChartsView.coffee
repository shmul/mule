Ext.define "Muleview.view.SingleGraphChartsView",
  extend: "Muleview.view.ChartsView"
  requires: [
    "Muleview.view.AlertsEditor"
  ]

  initComponent: ->
    this.keys = [@key]
    this.callParent()

  renderChart: (retName = @currentRetName) ->
    @chartContainer.removeAll()
    @chartContainer.setLoading(true)
    Muleview.Mule.getGraphData @key, retName, (data) =>
      @chartContainer.setLoading(false)
      store = @createStore(data)
      window.s=store
      console.log('SingleGraphChartsView.coffee\\ 38: store:', store);
      keys = Ext.Object.getKeys(data)
      subkeys = Ext.Array.difference(keys, [@key])
      @chartContainer.add Ext.create "Muleview.view.MuleChart",
        flex: 1
        showAreas: true
        topKeys: [@key]
        subKeys: subkeys
        # alerts: @alerts[retName]
        store: store
        showLegend: @showLegend

      @setBbar(store)
