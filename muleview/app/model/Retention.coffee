Ext.define "Muleview.model.Retention",
  extend: "Ext.data.Model"
  fields: [
      name: "name"
      type: "string"
    ,
      name: "sortValue"
      type: "int"
    ,
      name: "title"
      type: "string"
  ]

  idProperty: "name"

  statics:
    units: [
      ["s", "Seconds"]
      ["m", "Minutes"]
      ["h", "Hours"]
      ["d", "Days"]
      ["y", "Years"]
    ]

  parseOne: (rawTimeUnit) ->
    [_all, count, letter] = rawTimeUnit.match(/(\d+)([mhsdy])/)
    name = null
    for [unitLetter, unitName], ind in @self.units
      if letter == unitLetter
        name = unitName
        letterIndex = ind
    count = parseInt(count)
    name = name.substring(0, name.length - 1) if count == 1 # Remove the "s" for a singular form
    {
      name: name
      count: count
      letter: letter
      letterValue: letterIndex
    }

  constructor: (ret) ->
    split = ret.split(":")
    last = split[1]
    @bucket = @parseOne(split[0])
    @total = @parseOne(split[1])
    @title = @getTitle()
    @value = @getValue()
    @callParent()
    @set
      name: ret
      title: @title
      sortValue: @value
    @

  # Returns a tab title for a graph,
  # examples:
  #   "5m:1d" => "Last 1 days"
  #   "1s:3y" => "Last 3 years"
  getTitle: ->
    "Every #{@bucket.count} #{@bucket.name} / Last #{@total.count} #{@total.name}"

  # Creates an integer value for a retention - this functions describes an order between all possible retentions:
  # Examples:
  #   getValue("1s:1y") > getValue("1s:100d")
  #   getValue("1m:5m") > getValue("10s:5m")
  getValue: ->
    base = 1000 # I assume there will be no more than 3 digits per unit
    ans = 0
    # Create an array, the order of which describes the calculated elements' weight
    elements = [
      @bucket.count
      @bucket.letterValue
      @total.count
      @total.letterValue
    ]
    ans += Math.pow(base, ind) * element for element, ind in elements
    ans