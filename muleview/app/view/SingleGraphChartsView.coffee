Ext.define "Muleview.view.SingleGraphChartsView",
  extend: "Muleview.view.ChartsView"
  requires: [
    "Muleview.view.AlertsEditor"
  ]

  showLegend: false

  initComponent: ->
    this.keys = [@key]
    this.callParent()

  createChart: (retName = @currentRetName) ->
    @chartContainer.removeAll()
    @chartContainer.setLoading(true)
    Muleview.Mule.getGraphData @key, retName, (data) =>
      @chartContainer.setLoading(false)
      @store = @createStore(data)
      @subkeys = Ext.Array.difference(Ext.Object.getKeys(data), [@key])
      @renderChart()
      @setBbar(@store)

  renderChart: ->
    @chartContainer.removeAll()
    @chartContainer.add Ext.create "Muleview.view.MuleChart",
      flex: 1
      showAreas: true
      topKeys: [@key]
      subKeys: @subkeys
      # alerts: @alerts[retName]
      store: @store
      showLegend: @showLegend
