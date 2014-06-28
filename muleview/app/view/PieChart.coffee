Ext.define "Muleview.view.PieChart",
  extend: "Ext.window.Window"
  modal: false
  resizeable: true
  width: "30%"
  height: "60%"
  layout: "fit"

  items: ->
    [
      @chartContainer = Ext.create "Ext.container.Container",
        layout: "fit"
    ]

  initComponent: ->
    @items = @items()
    formattedValue = Ext.util.Format.number(@value, ",")
    @title = "#{@key}:#{@retention} @ #{@formattedTimestamp}, total: #{formattedValue}"
    @addListener "afterrender", =>
      @chartContainer.setLoading(true)
      Muleview.Mule.getPieChartData @key, @retention, @timestamp, (data) =>
        @chartContainer.setLoading(false)
        @drawPieChart(data)
        window.s = @store
    @callParent()

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

    total = Ext.Array.sum(Ext.Array.pluck(data, "value"))

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
            width: 140
            trackMouse: true
            renderer: (storeItem, item) ->
              value = storeItem.get("value")
              valueFormatted = Ext.util.Format.number(value, ",")
              percent = value / total * 100
              percentFormatted = Ext.util.Format.number(percent, "0.00")
              @setTitle "#{valueFormatted} (#{percentFormatted}%)"

          highlight:
            segment:
              margin: 20
        }
      ]
    }
    @chartContainer.add @chart
