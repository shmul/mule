Ext.define "Muleview.view.SubkeysSelector",
  extend: "Ext.window.Window"
  requires: [
    "Ext.grid.column.CheckColumn"
  ]

  title: "Select Subkeys"
  modal: true
  hidden: true
  layout:
    type: "vbox"
    align: "stretch"
    pack: "start"
  autoScroll: true
  cls: "subkeys-selector"
  bodyPadding: 20
  items: ->
    [
      {
        xtype: "container"
        html: "Muleview can automatically group the least-important subkeys together to form a single area. <br/>You may customize which subkeys to show separately, and the others will be grouped.<hr/>"
        margin: "0px 0px 5px 0px"
      }
      {
        xtype: "container"
        html: "Subkey selection:"
        margin: "0px 0px 5px 0px"
      }

      {
        xtype: "radio"
        inputValue: "auto"
        name: "option"
        checked: @auto
        boxLabel: "<b>Automatic</b> - Select the " + (Muleview.Settings.defaultSubkeys + Muleview.Settings.subkeysOffsetAllowed) + " most significant subkeys"
        listeners:
          change: (me, value) =>
            @auto = value
            @enableGrid(!value)
      }

      {
        xtype: "radio"
        name: "option"
        checked: !@auto
        inputValue: "custom"
        boxLabel: "<b>Custom</b> - Select specific subkeys to display:"
      }

      @grid = Ext.create "Ext.grid.Panel", {
        xtype: "grid"
        disabled: @auto
        flex: 1
        store: @store
        columns: [
          {
            xtype: "checkcolumn"
            width: 50
            header: "Show"
            dataIndex: "selected"
          }

          {
            header: "Name"
            dataIndex: "name"
            flex: 3
            renderer: (name) ->
              name.substring(name.lastIndexOf(".") + 1)
          }

          {
            header: "Weight (heuristic)"
            flex: 1
            dataIndex: "weightPercentage"
            renderer: Ext.util.Format.numberRenderer("0.0%")
          }
        ]
      }
    ]
  bbar: ->
    [
      "->",
      {
        xtype: "button"
        width: 75
        text: "Cancel"
        handler: =>
          @cancel()
      },
      {
        xtype: "button"
        text: "OK"
        width: 75
        handler: =>
          @update()
      }
    ]

  enableGrid: (enable) ->
    @grid.setDisabled(!enable)

  cancel: ->
    @store.rejectChanges()
    @close()

  update: ->
    if @auto then @store.autoSelect() else @store.isAuto = false
    @store.commitChanges()
    @close()
    @callback.call(@callbackScope)

  initComponent: ->
    @height = Ext.dom.AbstractElement.getViewportHeight() * 0.6
    @width = Ext.dom.AbstractElement.getViewportWidth() * 0.4
    @auto = @store.isAuto
    @bbar = @bbar()
    @items = @items()
    @callParent()
