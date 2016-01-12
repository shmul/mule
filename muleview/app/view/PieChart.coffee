Ext.define "Muleview.view.PieChart",
  extend: "Ext.window.Window"
  requires: [
    "Ext.chart.series.Pie"
    "Ext.chart.Chart"
  ]
  modal: false
  resizeable: true
  maximizable: true
  minimizable: false # Minimizing doesn't work :(
  width: "40%"
  height: "60%"
  layout: "fit"

  items: ->
    [
      @chartContainer = Ext.create "Ext.container.Container",
        layout: "fit"
    ]

  updateTitle: () ->
    title = "#{@key}:#{@retention} @ #{@formattedTimestamp}"
    if @total
      formattedTotal = Ext.util.Format.number(@total, ",")
      title += ", total: #{formattedTotal}"
    @setTitle(title)


  initComponent: ->
    @items = @items()
    @addListener "afterrender", =>
      @chartContainer.setLoading(true)
      Muleview.Mule.getPieChartData @key, @retention, @timestamp, (data, topKeyTotal) =>
        @total = topKeyTotal
        @chartContainer.setLoading(false)
        @addOthersAndUnknown(data)
        @drawPieChart(data)
        @updateTitle()

    @callParent()
    @updateTitle()


  addOthersAndUnknown: (data) ->
    # Sort data from largest to smallest
    data = Ext.Array.sort(data, (a,b) -> b.value - a.value)

    actualTotal = Ext.Array.sum(Ext.Array.pluck(data, "value"))
    diff = @total - actualTotal
    if diff > 0
      data.push({
        value: diff,
        key: "[Unknown]"
      })
    @total = Math.max(@total, actualTotal)

    # Unify least-meaningful Others:
    if data.length > Muleview.Settings.maxPiechartSlices
      others = Ext.Array.splice(data, Muleview.Settings.maxPiechartSlices - 1, data.length)
      data.push
        key: "[Others]"
        value: Ext.Array.sum(Ext.Array.pluck(others, "value"))


  drawPieChart: (data) ->
    dataArr = Ext.Array.map data, (record) ->
      keyName = record.key.split(".").pop()
      [keyName, record.value]
    @store = Ext.create "Ext.data.ArrayStore", {
      fields: [
        {
          name: "key"
          type: "string"
        },

        {
          name: "value"
          type: "int"
        }
      ]
      data: dataArr
    }


    total = @total

    @chart = Ext.create "Ext.chart.Chart", {
      type: "pie"
      store: @store
      animate: true
      legend:
        position: "right"
      series: [
        {
          type: "pie",
          angleField: "value"
          showInLegend: true
          label:
            field: "key"
            display: "rotate"
            contrast: true
            font: "18px Arial"
          tips:
            width: 400
            trackMouse: true
            renderer: (storeItem, item) ->
              key = storeItem.get("key")
              value = storeItem.get("value")
              valueFormatted = Ext.util.Format.number(value, ",")
              percent = value / total * 100
              percentFormatted = Ext.util.Format.number(percent, "0.00")
              @setTitle "#{key} - #{valueFormatted} (#{percentFormatted}%)"

          highlight:
            segment:
              margin: 20
        }
      ]
    }
    @chartContainer.add @chart
