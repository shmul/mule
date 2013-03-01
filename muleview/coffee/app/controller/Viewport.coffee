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
  ]

  onLaunch: ->
    @control
      "#mainPanel":
        tabchange: @updateLightGraphs

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

  updateLightGraphs: (me, selectedTab)->
    @getRightPanel().items.each (lightGraph) ->
      lightGraph.setVisible(selectedTab.retention != lightGraph.retention)
