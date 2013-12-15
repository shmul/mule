Ext.define "Muleview.view.SingleGraphChartsView",
  extend: "Muleview.view.ChartsView"
  requires: [
    "Muleview.view.MuleChart"
    "Muleview.view.AlertsEditor"
  ]

  initComponent: ->
    @keys = [@key]
    this.callParent()
    @toolbar.insert 3, Ext.create "Ext.button.Button",
      text: "Edit Alerts"
      icon: "resources/default/images/alerts.png"
      handler: =>
        @showAlertsEditor()

  showAlertsEditor: ->
    ae = Ext.create "Muleview.view.AlertsEditor",
      key: @key
      retention: @currentRetName
      store: @store
    ae.show()

  createChart: (retName = @currentRetName) ->
    @chartContainer.removeAll()
    Muleview.Mule.getGraphData @key, retName, (data) =>
      @alerts = Ext.StoreManager.get("alertsStore").getById("#{@key};#{@currentRetName}")?.toGraphArray(@currentRetName)
      @store = @createStore(data, @alerts)
      @subkeys = Ext.Array.difference(Ext.Object.getKeys(data), [@key])
      @renderChart()

  renderChart: ->
    @chartContainer.removeAll()
    @chart = Ext.create "Muleview.view.MuleChart",
      flex: 1
      showAreas: true
      topKeys: [@key]
      subKeys: @subkeys
      alerts: @alerts
      store: @store
      title: "#{@key};#{@currentRetName}"
      listeners:
        closed: =>
          @legendClosed()

    @chartContainer.insert 0, @chart
    @chartContainer.setLoading(false)
