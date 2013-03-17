Ext.define "Muleview.controller.Viewport",
  extend: "Ext.app.Controller"
  requires: [
    "Muleview.Events"
  ]
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
        click: ->
          Muleview.Graphs.createGraphs()

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
    Muleview.Events.on
      graphRequest: @openGraph
      scope: @

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

  openGraph: (newKey, newRetention) ->
    # load graphs and set correct Muleview.currentKey
    Muleview.Graphs.createGraphs newKey, =>
      Muleview.currentRetention = newRetention if newRetention

      # Update titles:
      document.title = "Mule - #{Muleview.currentKey}"
      @getMainPanel().setTitle Muleview.currentKey.replace /\./g, " / "

      # Select correct tab:
      newTab = @getMainPanel().items.findBy (tab) ->
        tab.retention == Muleview.currentRetention
      newTab ||= @getMainPanel().items.first()
      @getMainPanel().setActiveTab(newTab)
      Muleview.currentRetention = newTab.retention

      # Update right-panel's light charts:
      @getRightPanel().items.each (lightGraph) ->
        lightGraph.setVisible(Muleview.currentRetention != lightGraph.retention)

      # Update alerts editor:
      @getAlertsEditor().load(
        Muleview.currentKey,
        Muleview.currentRetention,
        Muleview.Graphs.retentions[Muleview.currentRetention]?.alerts); # TODO: refactor

      # Update history:
      Ext.History.add Muleview.currentKey + ";" + Muleview.currentRetention

      # Update other components
      Muleview.event "graphChanged", Muleview.currentKey, Muleview.currentRetention

  onTabChange: (me, selectedTab)->
    @openGraph null, selectedTab.retention
