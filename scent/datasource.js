// all data items on the page come from here. We can work in mockup or real world mode

function scent_ds_mockup (ready_) {
  var fixtures_scripts = ["config","key","graph","alert"];
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
    var gr = fixtures["graph"];
    return gr[graph_name_];
  }

  function load_settings(user_) {
  }

  function save_settings(user_,settings_) {
  }

  return {
    critical : function() { return alerts("critical"); },
    graph : graph,
    load_settings: load_settings,
    save_settings: save_settings,
  }


};


scent_ds = scent_ds_mockup();
