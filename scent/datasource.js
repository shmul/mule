// all data items on the page come from here. We can work in mockup or real world mode

function scent_ds_mockup (ready_) {
  var fixtures_scripts = ["s3.phishing","httpreq","alerts"];
  var fixtures = {};

  function load_fixture(name_,path_) {
    $.ajax({
      url: "./fixtures/"+name_+".json",
      async: false,
      dataType: 'json',
      success: function (response_) {
        fixtures[name_] = response_.data;
      }
    });
  }


  for (var f in fixtures_scripts) {
    load_fixture(fixtures_scripts[f]);
  }

  function alerts(alert_type_) {
    if ( alert_type_=="critical" ) {

    }
  }

  function graph(graph_name_) {
    var gr = fixtures[graph_name_];
    if ( gr["httpreq.frontend_messaging.304;1h:90d"] ) {
      return ["httpreq.frontend_messaging.304;1h:90d",gr];
    }
    if ( gr["download_from_s3.downloads.phishing_constant_patterns;1h:90d"] ) {
      return ["download_from_s3.downloads.phishing_constant_patterns;1h:90d",gr];
    }
  }

  return {
    critical : function() { return alerts("critical"); },
    graph : graph,
  }


};


scent_ds = scent_ds_mockup();
