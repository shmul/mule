// all data items on the page come from here. We can work in mockup or real world mode

function scent_ds_mockup () {
  var fixtures = ["s3.phishing","httpreq","alerts"];
  for (var f in fixtures) {
    jQuery.getScript("./fixtures/"+fixtures[f]+".json");
  }

  function alerts(alert_type_) {
    if ( alert_type_=="critical" ) {

    }
  }

  function graph(graph_name_) {

  }

  return {
    critical : function() { return alerts("critical"); },
  }


};
