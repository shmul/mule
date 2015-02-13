
function app() {
  function load_graph(graph_,target_) {
    var graph = scent_ds.graph(graph_);
    var raw_data = graph[1][graph[0]];
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
      title: graph[0],
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
  }

  load_graph("httpreq","#chart-1");
  load_graph("httpreq","#chart-2");
  load_graph("httpreq","#chart-3");
  /*
    $(function() {
    $('#chart-1').on('click', function() {
    alert("chart-1");
    });
    });
  */

}


$(app);
