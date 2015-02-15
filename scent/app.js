
function app() {
  var user = "Shmul the mule";

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
    graph.render();
/*
    var annotator = new Rickshaw.Graph.Annotate({
      graph: graph,
      element: document.querySelector(target_+'-timeline')
    });
    annotator.add(1423785600,"hello cruel world");
		annotator.update();
*/
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

  function setup_alerts_menu() {
    var template_data = [
      {Name: "Critical", name: "critical", indicator: "danger", color: "red"},
      {Name: "Warning", name: "warning", indicator: "warning", color: "orange"},
      {Name: "Anomaly", name: "anomaly", indicator: "info", color: "blue"},
      {Name: "Stale", name: "stale", indicator: "info", color: "light-blue"},
      {Name: "Normal", name: "normal", indicator: "success", color: "green"}
    ];
    $("#alerts-menu-container").html($.templates("#alerts-menu-template").render(template_data));
  }
  function update_alerts() {
    var raw_data = scent_ds.alerts();
    // 0-critical, 1-warning, 2-anomaly, 3-Stale, 4-Normal
    function translate(i) {
      switch (i) {
      case 0: return { title: "Critical", type: "critical"};
      case 1: return { title: "Warning", type: "warning"};
      case 2: return { title: "Anomaly", type: "anomaly"};
      case 3: return { title: "Stale", type: "stale"};
      case 4: return { title: "Normal", type: "normal"};
      }
      return {}
    }
    var date_format = d3.time.format("%Y-%M-%d:%H%M%S");
    var alerts = [[],[],[],[],[]];
    for (n in raw_data) {
      var current = raw_data[n];
      var idx = -1;
      switch ( current[7] ) {
      case "CRITICAL LOW":
      case "CRITICAL HIGH": idx = 0; break;
      case "WARNING LOW":
      case "WARNING HIGH": idx = 1; break;
      case "stale": idx = 3; break;
      case "NORMAL": idx = 4; break;
      }
      if ( idx!=-1 ) {
        alerts[idx].push([n,current]);
      }
    }
    var anomalies = raw_data["anomalies"];
    for (n in anomalies) {
      alerts[2].push([n,anomalies[n]]);
    }

    var template_data = [];
    for (var i=0; i<5; ++i) {
      var len = alerts[i].length;
      var tr = translate(i);
      $("#alert-menu-"+tr.type).text(len);
      var d = [];
      for (var j=0; j<len; ++j) {
        if ( i==2 ) { //anomalies
          var cur = alerts[i][j][1];
          cur.sort();
          d.push({
            graph : alerts[i][j][0],
            time : date_format(new Date(cur[0]*1000)),
            type : "anomaly" // this is needed for jsrender's predicate in the loop
          });
        } else {
          var cur = alerts[i][j][1];
          d.push({
            graph : alerts[i][j][0],
            time : date_format(new Date(cur[8]*1000)),
            value : cur[6],
            crit_high : cur[3],
            warn_high : cur[2],
            warn_low : cur[1],
            crit_low : cur[0],
            stale : cur[5],
          });
        }
      }
      template_data.push({title:tr.title,type:tr.type,records:d});
    }
    $("#alert-container").html($.templates("#alert-template").render(template_data));
    for (var i=0; i<5; ++i) {
      var tr = translate(i);
      $("#alert-"+tr.type).dataTable();
    }
  }

  function load_graphs_lists(list_name_,data_) {
    if ( data_ && data_.length>0 ) {
      var template_data = [];
      for (var d=0; d<data_.length; ++d) {
        template_data.push({idx:1+d, name:data_[d]});
      }
      $("#"+list_name_+"-container").append($.templates("#"+list_name_+"-template").render(template_data));
    }
  }
  var persistent = scent_ds.load(user,"persistent");
  var favorites = persistent.favorites;
  var recent = scent_ds.load(user,"recent");
  load_graphs_lists("favorite",favorites);
  load_graphs_lists("recent",recent);

  $(window).bind('hashchange', function () { //detect hash change
    var hash = window.location.hash.slice(1); //hash to string (= "myanchor")
    //do sth here, hell yeah!
    });


  function build_graph_cell(parent_,idx_) {
    var template = $.templates("#chart-template");
    $(parent_).append(template.render([{idx:idx_}]));
    return "chart-"+idx_;
  }

  for (i=1; i<=4; ++i) {
    var name = build_graph_cell($("#charts-container"),i);
    var g = i%2==0 ? "brave;5m:3d" : "kashmir_report_db_storer;1d:2y";
    load_graph(g,"#"+name,"#"+name+"-label");
  }
  setup_alerts_menu();
  update_alerts();

  $(".modal-wide").on("show.bs.modal", function() {
    var height = $(window).height();
    $(this).find(".modal-body").css("max-height", height);
  });
}


$(app);
