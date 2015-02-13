
function app() {
  function load_graph(name_,target_,label_,no_modal_) {
    var raw_data = scent_ds.graph(name_);
    var data = [];
    var m = 0;
    for (var rw in raw_data) {
      var dt = raw_data[rw][2];
      var v = raw_data[rw][0];
      if ( dt>100000 ) {
        data.push({x:dt, y:v});
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
    $(label_).text(name_);

    if ( !no_modal_ ) {
      $(target_).on('click', function() {
        load_graph(name_,"#modal-body","#modal-label",true);
        var el = $("#modal-target");
        $("#modal-target").modal('show');
      });
      // cleanup
      $('#modal-target').on('hidden.bs.modal', function (e) {
        $("#modal-body").html("");
      });
    }
  }

  function update_alerts() {
    var raw_data = scent_ds.alerts();
    // 0-critical, 1-warning, 2-anomaly, 3-normal
    var alerts = [[],[],[],[]];
    for (n in raw_data) {
      var current = raw_data[n];
      var idx = -1;
      switch ( current[7] ) {
      case "CRITICAL LOW":
      case "CRITICAL HIGH": idx = 0; break;
      case "WARNING LOW":
      case "WARNING HIGH": idx = 1; break;
      case "NORMAL": idx = 3; break;
      }
      if ( idx!=-1 ) {
        alerts[idx].push(current);
      }
    }
    var anomalies = raw_data["anomalies"];
    for (n in anomalies) {
      alerts[2].push(anomalies[n]);
    }
    for (i=0; i<4; ++i) {
      $("#alert-"+(i+1)).text(alerts[i].length);
    }
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
    var g = i%2==0 ? "brave;5m:3d" : "kashmir_report_db_storer;1d:2y";
    load_graph(g,"#"+name,"#"+name+"-label");
  }
  update_alerts();
}


$(app);
