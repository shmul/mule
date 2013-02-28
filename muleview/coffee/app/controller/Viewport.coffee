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
  ]

  onLaunch: ->
    @control
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
    console.log("Viewport.coffee\\ 46: <HERE>");
    expanded = @isMainPanelExpanded()
    if expanded
      @getMainPanelMaximize().hide()
      @getMainPanelRestore().show()
    else
      @getMainPanelMaximize().show()
      @getMainPanelRestore().hide()