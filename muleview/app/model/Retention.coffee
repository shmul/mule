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
      ["s", "Second", 1]
      ["m", "Minute", 60]
      ["h", "Hour", 60 * 60]
      ["d", "Day", 60 * 60 * 24]
      ["y", "Year", 60 * 60 * 24 * 365]
    ]

    # Receives something like "5s", "2m" or "1h",
    # Returns something like 5, 120, 3600
    getMuleTimeValue: (str) ->
      parsed = @parseOne(str)
      [_, _, size] = Ext.Array.findBy @units, (unit) ->
        [letter, _, _] = unit
        letter == parsed.letter
      parsed.count * size

    toLongFormat: (secs) ->
      ans = []
      for [_, devider, size], i in @units by -1
        if secs >= size
          remainder = secs % size
          subtract = (secs - remainder) / size
          secs = remainder
          ans.push(if remainder == 0 then " and " else ", ") if ans.length > 0
          ans.push "#{subtract} #{devider}"
          ans.push "s" if subtract > 1
      ans.join("")

    toShortFormat: (secs) ->
      for [letter, _, size] in @units by -1
        return "#{secs / size}#{letter}" if secs % size == 0

    parseOne: (rawTimeUnit) ->
      [_all, count, letter] = rawTimeUnit.match(/(\d+)([mhsdy])/)
      name = null
      for [unitLetter, unitName, size], ind in @units
        if letter == unitLetter
          name = unitName
          letterIndex = ind
          letterSize = size
      count = parseInt(count)
      secs = letterSize * count
      name += "s" if count > 1 # Add "s" for plural form
      {
        name: name
        count: count
        letter: letter
        letterValue: letterIndex
        secs: secs
      }

  constructor: (ret) ->
    split = ret.split(":")
    last = split[1]
    @bucket = @self.parseOne(split[0])
    @total = @self.parseOne(split[1])
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
    "Last #{@total.count} #{@total.name} (Every #{@bucket.count} #{@bucket.name})"

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

  # Returns the step size
  getStep: ->
    @bucket.secs
