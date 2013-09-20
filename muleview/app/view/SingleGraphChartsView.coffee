Ext.define "Muleview.view.SingleGraphChartsView",
  extend: "Muleview.view.ChartsView"
  requires: [
    "Muleview.store.SubkeysStore"
    "Muleview.view.SubkeysSelector"
    "Muleview.view.AlertsEditor"
  ]
  othersKey: Muleview.Settings.othersSubkeyName # Will be used as the name for the key which will group all hidden subkeys

  # Replace full Mule key names as keys with retention-name only
  processAlertsHash: (alerts) ->
    ans = {}
    for own k, v of alerts
      [muleKey, ret] = k.split(";")
      ans[ret] = v if muleKey == @key
    ans

  initComponent: ->
    this.topKeys = [@key]
    this.callParent()

  initKeys: ->
    this.callParent()
    @subKeys = Ext.Array.difference(@keys, [@key])
    @keys.push(@othersKey) # Need to add othersKey as a key so that the records will have such an attribute

  initStores: ->
    # Rename alerts' keys to be hashed only by the retName
    @alerts = @processAlertsHash(@alerts)

    this.callParent()
    # Init the subkeys-store to calculate which subkeys its best to show first:
    @subkeysStore = Ext.create "Muleview.store.SubkeysStore",
      dataStore: @stores[@defaultRetention]
    @subkeysStore.loadSubkeys(@subKeys)

    # Hide the legend if no subkeys exist:
    @showLegend = @subKeys.length > 0

  showAlertsEditor: () ->
    ae = Ext.create "Muleview.view.AlertsEditor",
      alertName: "#{@key};#{@currentRetName}"
    ae.show()

  showSubkeysSelector: ->
    subkeysSelector = Ext.create "Muleview.view.SubkeysSelector",
      store: @subkeysStore
      callback: @renderChart
      callbackScope: @
    subkeysSelector.show()

  renderChart: (retName = @currentRetName) ->
    @chartContainer.removeAll()
    @selectedSubkeys = @subkeysStore.getSelectedNames()
    store = @stores[retName]
    unselectedSubkeys = Ext.Array.difference(@subKeys, @selectedSubkeys)
    if unselectedSubkeys.length > 0
      @selectedSubkeys.push(@othersKey)
      store.each (record) =>
        sum = 0
        sum += record.get(otherSubkey) for otherSubkey in unselectedSubkeys
        record.set(@othersKey, sum)
    @chartContainer.add Ext.create "Muleview.view.MuleChart",
      flex: 1
      showAreas: true
      topKeys: [@key]
      subKeys: @selectedSubkeys
      listeners:
        othersKeyClicked: =>
          @showSubkeysSelector()
      alerts: @alerts[retName]
      store: store
      showLegend: @showLegend

    @setBbar(store)

  createChartContainerToolbar: ->
    toolbar = this.callParent()
    toolbar.splice(2,0,
      "-",
        xtype: "button"
        text: "Edit Alerts"
        icon: "resources/default/images/alerts.png"
        handler: =>
          @showAlertsEditor()
    , "-",
        xtype: "button"
        text: "Select Subkeys"
        icon: "resources/default/images/subkeys.png"
        disabled: @subKeys.length == 0
        handler: =>
          @showSubkeysSelector()
        )
    toolbar
