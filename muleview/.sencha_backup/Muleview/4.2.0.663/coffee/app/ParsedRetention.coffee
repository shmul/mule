Ext.define "Muleview.ParsedRetention",
  statics:
    units: [
      ["s", "seconds"]
      ["m", "minutes"]
      ["h", "hours"]
      ["d", "days"]
      ["y", "years"]
    ]

  parseOne: (rawTimeUnit) ->
    [_all, count, letter] = rawTimeUnit.match(/(\d+)([mhsdy])/)
    name = null
    for [unitLetter, unitName], ind in @self.units
      if letter == unitLetter
        name = unitName
        letterIndex = ind
    name = name.substring(0, name.length - 1) if count = 1 # Remove the "s" for a singular form
    {
      name: name
      count: parseInt(count)
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
    @

  # Returns a tab title for a graph,
  # examples:
  #   "5m:1d" => "Last 1 days"
  #   "1s:3y" => "Last 3 years"
  getTitle: ->
    "Last #{@total.count} #{@total.name}"

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