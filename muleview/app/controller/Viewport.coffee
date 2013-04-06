Ext.define "Muleview.controller.Viewport",
  extend: "Ext.app.Controller"
  refs: [
      ref: "leftPanel"
      selector: "#leftPanel"
    ,
      ref: "rightPanel"
      selector: "#rightPanel"
    ,
      ref: "mainPanelMaximize"
      selector: "#mainPanelMaximize"
    ,
      ref: "mainPanelRestore"
      selector: "#mainPanelRestore"
    ,
      ref: "mainPanel"
      selector: "#mainPanel"
    ,
      ref: "alertsEditor"
      selector: "#alertsEditor"
  ]

  onLaunch: ->
    @control
      "#mainPanel":
        tabchange: @onTabChange
      "#mainPanelRefresh":
        click: =>
          @refreshGraph()

      "#mainPanelMaximize":
        click: @togglePanels

      "#mainPanelRestore":
        click: @togglePanels

      "#leftPanel":
        collapse: @updateMainPanelTools
        expand: @updateMainPanelTools

      "#rightPanel":
        collapse: @updateMainPanelTools
        expand: @updateMainPanelTools

    @getMainPanel().getEl().addListener("dblclick", @togglePanels, @)
    Muleview.app.on
      graphRequest: (key, retention) =>
        @openGraph key, retention
      refreshRequest: =>
        @refreshGraph()

  isMainPanelExpanded: ->
    @getLeftPanel().getCollapsed() and @getRightPanel().getCollapsed()

  togglePanels: ->
    expanded = @isMainPanelExpanded()

    if expanded
      @getLeftPanel().expand(false)
      @getRightPanel().expand(false)
    else
      @getLeftPanel().collapse(Ext.Component.DIRECTION_LEFT)
      @getRightPanel().collapse(Ext.Component.DIRECTION_RIGHT)

    @updateMainPanelTools()

  updateMainPanelTools: ->
    expanded = @isMainPanelExpanded()
    @getMainPanelMaximize().setVisible(!expanded)
    @getMainPanelRestore().setVisible(expanded)

  refreshGraph: ->
    @openGraph Muleview.currentKey, Muleview.currentRetention, true

  openGraph: (newKey, newRetention, refresh) ->
    console.log('Viewport.coffee\\ 76: arguments:', arguments);
    return;
    if newKey != Muleview.currentKey or refresh
      # If a different key is requested, create the new graphs:
      Muleview.Graphs.createGraphs newKey, =>
        @updateDisplay(newKey, newRetention)
    else if newRetention != Muleview.currentRetention
      # If only a new retention is requested, update the view accordingly:
      @updateDisplay(newKey, newRetention)

  updateDisplay: (newKey, newRetention) ->
    Muleview.currentKey = newKey
    Muleview.currentRetention = newRetention

    # Update titles:
    document.title = "Mule - #{Muleview.currentKey}"
    @getMainPanel().setTitle Muleview.currentKey.replace /\./g, " / "

    # Select the specified or the first tab:
    Muleview.currentRetention ||= @getMainPanel().items.first().retention
    newTab = @getMainPanel().items.findBy (tab) ->
      tab.retention == Muleview.currentRetention
    @getMainPanel().setActiveTab(newTab)

    # Update right-panel's light charts:
    @getRightPanel().items.each (lightGraph) ->
      lightGraph.setVisible(Muleview.currentRetention != lightGraph.retention)

    # Update alerts editor:
    @getAlertsEditor().load(
      Muleview.currentKey,
      Muleview.currentRetention,
      Muleview.Graphs.retentions[Muleview.currentRetention]?.alerts); # TODO: refactor

    # Update history:
    Ext.History.add Muleview.currentKey + ";" + Muleview.currentRetention # TODO: refactor

    # Update other components (i.e. keysTree's selection)
    Muleview.event "graphChanged", Muleview.currentKey, Muleview.currentRetention

  onTabChange: (me, selectedTab)->
    @openGraph Muleview.currentKey, selectedTab.retention
