Ext.define "Muleview.store.SubkeysStore",
  extend: "Ext.data.ArrayStore"

  isAuto: true
  fields: [
      name: "name"
      type: "string"
    ,
      name: "selected"
      type: "boolean"
    ,
      name: "heuristicWeight"
      type: "int"
  ]

  loadSubkeys: (subkeys)->
    @add(({name: key, selected: false, heuristicWeight: 0} for key in subkeys))
    @autoSelect()

  getSelectedNames: ->
    ans = []
    @each (record) ->
      ans.push(record.get("name")) if record.get("selected")
    ans

  autoSelect: (newStore) ->
    @dataStore = newStore if newStore

    @each (subkey) ->
      subkey.set("heuristicWeight", subkey.get("name").length)

    @sort "heuristicWeight", "DESC"

    for ind in [0...@getCount()]
      record = @getAt(ind)
      record.set "selected", ind <= Muleview.Settings.defaultSubkeys
    @isAuto = true
    @commitChanges()
    @getSelectedNames()
