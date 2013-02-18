Ext.define "Muleview.view.MuleChart",
  extend:  "Ext.chart.Chart"
  requires: [
    "Muleview.store.ChartStore"
  ]
  # store: chartStore
  series: [
    {
      type: 'line'
      xField: 'timestamp'
      yField: 'count'
      highlight: true
    }
  ]
  axes: [
    {
      title: "When?"
      type: "Numeric"
      position: "bottom"
      fields: ["timestamp"]
      label:
        renderer: (timestamp) ->
          Ext.Date.format(new Date(timestamp * 1000), Muleview.Settings.labelFormat)
        rotate:
          degrees: 315
      grid: true
    },

    {
      title: 'Count'
      type: 'Numeric'
      position: 'left'
      fields: ['count']
      minimum: 0
      grid: true
    }
  ]

  legend:
    position: "right"
  animate: true
