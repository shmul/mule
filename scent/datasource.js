// all data items on the page come from here. We can work in mockup or real world mode

function scent_ds_mockup (ready_) {
  var fixtures_scripts = ["config","key","graph","alert"];
  var fixtures = {};
  const user = "Shmul the mule";

  save(user,"recent",
       ["brave.backend;1d:2y",
        "event.activation_failed;5m:3d",
        "kashmir_report_db_storer;5m:3d"]);
  save(user,"persistent",
       {favorites:["event.bho_blocked_blacklisted;1h:90d",
                   "event.browser_apc_detected;1h:90d",
                   "event.buka_mr_result;1d:2y"]
       });

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

  function config() {
    return fixtures["config"];
  }

  function graph(graph_name_) {
    var gr = fixtures["graph"];
    return gr[graph_name_];
  }

  function key(key_) {
    var ky = fixtures["key"];
    return ky[key_];
  }

  function alerts(graph_name_) {
    return fixtures["alert"];
  }

  // if key == "persistent" the data is taken from the server, otherwise session storage
  // is used
  function load(user_,key_) {
    if (key_=="persistent" ) {
      return $.localStorage.get(user_+".persistent");
    }
    return $.sessionStorage.get(user_+"."+key_);
  }

  function save(user_,key_,data_) {
    if (key_=="persistent" ) {
      $.localStorage.set(user_+".persistent",data_);
      return;
    }
    $.sessionStorage.set(user_+"."+key_,data_);
  }

  return {
    critical : function() { return alerts("critical"); },
    config : config,
    graph : graph,
    key : key,
    alerts : alerts,
    load: load,
    save: save,
  }


};


scent_ds = scent_ds_mockup();
