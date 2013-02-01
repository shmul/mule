(function() {
  var graphContainer, treePanel;

  graphContainer = Ext.create("Ext.panel.Panel", {
    title: "Muleview",
    region: "center",
    html: 'Hello! Welcome to Ext JS.'
  });

  treePanel = Ext.create("Ext.tree.Panel", {
    region: "west",
    title: "Available Keys",
    width: "20%",
    split: true,
    root: {
      text: "Root key"
    }
  });

  Ext.application({
    name: "Muleview",
    launch: function() {
      return Ext.create("Ext.container.Viewport", {
        layout: "border",
        items: [treePanel, graphContainer]
      });
    }
  });

}).call(this);
