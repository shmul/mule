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


  function graph(graph_name_) {
    var gr = fixtures["graph"];
    return gr[graph_name_];
  }

  function alerts(graph_name_) {
    return fixtures["alert"];
  }

  // if key == "persistent" the data is taken from the server, otherwise session storage
  // is used
  function load(user_,key_) {
    if (key_=="persistent" ) {
      return localStorage[user_];
    }
    return sessionStorage[user_][key_];
  }

  function save(user_,key_,data_) {
    if (key_=="persistent" ) {
      localStorage[user_][key_] = data_;
      return;
    }
    sessionStorage[user_][key_] = data_;
  }

  return {
    critical : function() { return alerts("critical"); },
    graph : graph,
    keys : keys,
    alerts : alerts,
    load: load,
    save: save,
  }


};


scent_ds = scent_ds_mockup();
