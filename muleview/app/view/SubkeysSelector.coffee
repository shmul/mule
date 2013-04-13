Ext.define "Muleview.view.SubkeysSelector",
  extend: "Ext.window.Window"
  requires: [
    "Ext.grid.column.CheckColumn"
  ]

  title: "Select Subkeys"
  modal: true
  height: "60%"
  width: "40%"
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
        xtype: "radio"
        inputValue: "auto"
        name: "option"
        checked: @auto
        boxLabel: "Automatic"
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
        boxLabel: "Custom"
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
            renderer: Ext.util.Format.numberRenderer("0.00%")
          }
        ]
      }
    ]
  bbar: ->
    [
      "->",
      {
        xtype: "button"
        text: "Cancel"
        handler: =>
          @cancel()
      },
      {
        xtype: "button"
        text: "OK"
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
    @auto = @store.isAuto
    @bbar = @bbar()
    @items = @items()
    @callParent()
