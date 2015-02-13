
function app() {
  function load_graph(graph_,target_,label_) {
    var graph = scent_ds.graph(graph_);
    var name = graph[0];
    var raw_data = graph[1][name];
    var data = [];

    for (var rw in raw_data) {
      var dt = raw_data[rw][2];
      if ( dt>100000 ) {
        data.push({date:new Date(dt*1000),value:raw_data[rw][0]});
      }
    };
    data.sort(function(a,b) { return a.date-b.date });


    var markers = [{
      'date': new Date('2014-05-01T00:00:00.000Z'),
      'label': 'Anomaly'
    }];

    MG.data_graphic({
      //title: graph[0],
      data: data,
      markers: markers,
      show_secondary_x_label: false,
      //markers: [{'year': 1964, 'label': '"The Creeping Terror" released'}],
      full_width: true,
      full_height: true,
      target: target_,
      //x_accessor: "date-time",
      //y_accessor: "sightings",
      //interpolate: "monotone",
      missing_is_zero: true,
    });
    $(label_).text(name);
    return name;
  }

  load_graph("httpreq","#chart-1","#chart-1-label");
  load_graph("httpreq","#chart-2","#chart-2-label");
  load_graph("httpreq","#chart-3","#chart-3-label");

  $('#chart-1').on('click', function() {
    load_graph("httpreq","#modal-body","#modal-label");
    var el = $("#modal-target");
    $("#modal-target").modal('show');
  });
}


$(app);
