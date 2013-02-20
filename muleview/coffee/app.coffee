Ext.Loader.setPath("Muleview", "app")

Ext.application
  name: "Muleview"
  requires: [
    "Ext.container.Viewport",
    "Ext.tree.Panel",
    "Muleview.Settings",
    "Muleview.Mule"
  ]

  controllers: [
    "KeysTree"
  ]

  launch: ->
    Ext.create "Ext.container.Viewport", {
      layout: "border"
      items: [
        {
          xtype: "treepanel"
          id: "keysTree"
          region: "west"
          collapsible: true
          title: "Available Keys"
          width: "20%"
          split: true
          displayField: "name"
          rootVisible: false
        },
        {
          id: "mainPanel"
          xtype: "tabpanel"
          title: "Main View"
          region: "center"
          layout: "fit"
          items: [ ]
        },
        {
          id: "rightPanel"
          width: "20%"
          split: true
          xtype: "panel"
          region: "east"
          collapsible: true
          title: "Other Views"
          layout:
            type: "vbox"
            align: "stretch"
          defaults:
            flex: 1
        }
      ]
    }
    Muleview.createGraphs = @createGraphs
    Muleview.createMuleRecord = @createMuleRecord
    # setInterval(@pullData, Muleview.Settings.updateInterval)

  createGraphs: ->

    parseLightGraphTitle = (ret) ->
      console.log("MuleLightChart.coffee\\ 11: ret:", ret);
      split = ret.split(":")
      console.log("MuleLightChart.coffee\\ 13: split:", split);
      last = split[1]
      console.log("MuleLightChart.coffee\\ 12: last:", last);
      [_, count, letter] = match = last.match /(\d+)([mhsdy])/
      console.log("MuleLightChart.coffee\\ 14: match:", match);
      console.log("MuleLightChart.coffee\\ 15: count:", count);
      console.log("MuleLightChart.coffee\\ 16: letter:", letter);
      console.log("MuleLightChart.coffee\\ 17: @unitLetters:", @unitLetters);
      units = {
        "h": "hours"
        "m": "minutes"
        "d": "days"
      }[letter]
      console.log("MuleLightChart.coffee\\ 19: units:", units);
      "Last #{count} #{units}"

    tabPanel = Ext.getCmp("mainPanel")
    rightPanel = Ext.getCmp("rightPanel")

    tabPanel.removeAll();
    rightPanel.removeAll()

    Muleview.Mule.getKeyData Muleview.currentKey, (data) =>
      # Data is in the form "key => retention => data", so we need to reverse it to retention-based first:
      retentions = {}
      for key, rets of data
        for retention, retentionData of rets
          retentions[retention] ||= {}
          retentions[retention][key] = retentionData

      first_created = false
      # Now, create a graph for each retention:
      for ret, retData of retentions
        do (ret, retData) ->
          mainGraphPanel = Ext.create "Ext.panel.Panel",
            title: ret
            layout: "fit"
            items: [
              Ext.create "Muleview.view.MuleChart",
                showAreas: true
                data: retData
                topKey: Muleview.currentKey
            ]
          lightGraph = Ext.create "Muleview.view.MuleLightChart",
            data: retData
            title: Muleview.currentKey
            topKey: Muleview.currentKey
            listeners:
              mouseenter: ->
                tabPanel.setActiveTab(mainGraphPanel)

          tabPanel.add mainGraphPanel
          rightPanel.add Ext.create "Ext.form.FieldSet",
            layout: "fit"
            title: parseLightGraphTitle(ret)
            border: false
            frame: false
            items: [lightGraph]

      tabPanel.setActiveTab(0)