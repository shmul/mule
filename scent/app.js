
function app() {
  function load_graph(graph_,target_,label_) {
    var graph = scent_ds.graph(graph_);
    var name = graph[0];
    var raw_data = graph[1][name];
    var data = [];

    for (var rw in raw_data) {
      var dt = raw_data[rw][2];
      if ( dt>100000 ) {
        data.push({x:dt, y:raw_data[rw][0]});
      }
    };
    data.sort(function(a,b) { return a.x-b.x });


    var markers = [{
      'date': new Date('2014-05-01T00:00:00.000Z'),
      'label': 'Anomaly'
    }];

    var graph = new Rickshaw.Graph( {
      element: document.querySelector(target_),
      renderer: 'line',
      series: [ {
        color: 'steelblue',
        name: '', // this is required to shoosh the 'undefined in the tooltop'
        data: data
      } ]
    } );
    var hoverDetail = new Rickshaw.Graph.HoverDetail( {
	    graph: graph
    } );

    const ticksTreatment = 'glow';
    var x_axis = new Rickshaw.Graph.Axis.Time( {
	    graph: graph,
	    ticksTreatment: ticksTreatment,
	    timeFixture: new Rickshaw.Fixtures.Time.Local()
    } );
    var y_axis = new Rickshaw.Graph.Axis.Y( {
      graph: graph,
      tickFormat: Rickshaw.Fixtures.Number.formatKMBT,
      ticksTreatment: ticksTreatment
    } );

    x_axis.render();
    y_axis.render();
    graph.render();
    $(label_).text(name);

    $(target_).on('click', function() {
      load_graph("httpreq","#modal-body","#modal-label");
      var el = $("#modal-target");
      $("#modal-target").modal('show');
    });

    return name;
  }




  function build_graph_cell(parent_,idx_) {
    var cell = [
      '<div class="col-md-4">',
      '<div class="box box-primary">',
      '<div class="box-header">',
      '<h3 id="chart-'+idx_+'-label" class="box-title"></h3>',
      '</div>',
      '<div class="box-body">',
      '<div id="chart-'+idx_+'"></div>',
      '</div><!-- /.box-body-->',
      '</div><!-- /.box -->',
      '</div><!-- /.col -->'].join("");
    parent_.append(cell);
    return "chart-"+idx_;
  }

  for (i=1; i<=4; ++i) {
    var name = build_graph_cell($("#charts-container"),i);
    load_graph("httpreq","#"+name,"#"+name+"-label");
  }

}


$(app);
