Ext.define "Muleview.store.SubkeysStore",
  extend: "Ext.data.ArrayStore"
  requires: [
    "Muleview.Settings"
  ]

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
    ,
      name: "weightPercentage"
      type: "float"
  ]

  loadSubkeys: (subkeys)->
    @add(({name: key, selected: false, heuristicWeight: 0} for key in subkeys))
    @initHeuristics()
    @autoSelect()

  getSelectedNames: ->
    ans = []
    @each (record) ->
      ans.push(record.get("name")) if record.get("selected")
    ans

  initHeuristics: ->
    conf = Muleview.Settings.subkeyHeuristics
    sampleCount = conf.sampleCount

    @sampleIndexes = []
    for ind in [0...sampleCount]
      sampleIndex = Math.round @exponentIndex(ind, sampleCount - 1, 0, @dataStore.getCount() - 1) # Magic
      coefficient = @exponentIndex(sampleCount - ind - 1, sampleCount - 1, conf.coefficientMin, conf.coefficientMax)
      @sampleIndexes.push({index: sampleIndex, coefficient: coefficient})

  # Tranpose an index to some value, having
  #   the first index (0) mapped to minTarget,
  #   the last index (maxInd) mapped to maxTarget
  #   all other indexes mapped to the area between minTarget and maxTarget,
  #   concentrating -most- indices in the lower (smaller) area between the limits
  #   resulting in something like this:
  #   Lets say we have 5 indices, then they'll be mapped in a way similar to this:
  #   min----------------------------------------------------------------------max
  #   0 1    2           3                    4                                5
  exponentIndex: (ind, maxInd, minTarget, maxTarget) ->
    base = Muleview.Settings.subkeyHeuristics.base
    @transposeRelative 1, Math.pow(base, maxInd), minTarget, maxTarget, Math.pow(base, ind) # Magia

  # Transpose a number
  #   from a location in the area between minA and maxA
  #   to a relatively similar location between minB and maxB
  transposeRelative: (minA, maxA, minB, maxB, x) ->
    (((x - minA) * (maxB - minB)) / (maxA - minA )) + minB # Witchery

  estimateSubkeyWeight: (subkey) ->
    sum = 0
    for sampleIndex in @sampleIndexes
      weight = sampleIndex.coefficient * @dataStore.getAt(sampleIndex.index).get(subkey.get("name"))
      sum += weight
    subkey.set("heuristicWeight", sum)

  autoSelect: (newStore) ->
    if newStore
      @dataStore = newStore
      @initHeuristics()

    count = @getCount()
    @each (subkey) =>
      @estimateSubkeyWeight(subkey)

    totalWeight = @sum("heuristicWeight")
    @each (subkey) =>
      subkey.set("weightPercentage", 100 * subkey.get("heuristicWeight") / totalWeight)

    @sort "heuristicWeight", "DESC"

    for ind in [0...count]
      record = @getAt(ind)
      selected = count <= Muleview.Settings.defaultSubkeys + Muleview.Settings.subkeysOffsetAllowed
      selected ||= ind + 1 <= Muleview.Settings.defaultSubkeys
      record.set "selected", selected
    @isAuto = true
    @commitChanges()
    @getSelectedNames()
