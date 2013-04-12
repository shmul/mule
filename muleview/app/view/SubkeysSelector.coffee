Ext.define "Muleview.view.SubkeysSelector",
  extend: "Ext.window.Window"
  requires: [
    "Ext.grid.column.CheckColumn"
  ]

  height: 400
  width: 700
  title: "Select Subkeys"
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
        hideHeaders: true
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
        ,
          {
            header: "Name"
            dataIndex: "name"
            flex: 1
            renderer: (name) ->
              name.substring(name.lastIndexOf(".") + 1)
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
    @close()

  update: ->
    keys = null
    if !@auto
      keys = []
      @store.each (record) ->
        keys.push record.get("name") if record.get("selected")

    @close()
    @callback.call(@callbackScope, keys)

  initComponent: ->
    @bbar = @bbar()
    @store = @createStore()
    @items = @items()
    @callParent()

  createStore: ->
    data =  ([subkey, Ext.Array.contains(@selectedSubkeys, subkey)] for subkey in @availableSubkeys)
    Ext.create "Ext.data.ArrayStore",
      fields: [
          name: "name"
          type: "string"
        ,
          name: "selected"
          type: "boolean"
      ]
      data: data