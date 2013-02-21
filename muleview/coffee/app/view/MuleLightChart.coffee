Ext.define "Muleview.view.MuleLightChart",
  extend: "Ext.form.FieldSet"
  border: false
  frame: false
  layout: "fit"

  initComponent: ->
    @chart = Ext.create "Muleview.view.MuleChart",
      data: @data
      topKey: @topKey
      legend: false
      showAreas: false
      timeLabel:
        renderer: ->
          ""
    adjustEnd: false
    @items = [@chart]
    @title = @parseTitle(@retention)
    @callParent()

  parseTitle: (ret) ->
    split = ret.split(":")
    last = split[1]
    [_all, count, letter] = match = last.match /(\d+)([mhsdy])/
    units = {
      "h": "hours"
      "m": "minutes"
      "d": "days"
    }[letter]
    "Last #{count} #{units}"