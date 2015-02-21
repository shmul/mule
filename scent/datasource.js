// all data items on the page come from here. We can work in mockup or real world mode

function scent_ds_mockup (ready_) {
  var fixtures_scripts = ["config","key","graph","alert"];
  var fixtures = {};
  const user = "Shmul the mule";

  save(user,"recent",
       ["brave.backend;1d:2y",
        "event.activation_failed;5m:3d",
        "kashmir_report_db_storer;5m:3d"],function() {});
  save(user,"persistent",
       {favorites:["event.bho_blocked_blacklisted;1h:90d",
                   "event.browser_apc_detected;1h:90d",
                   "event.buka_mr_result;1d:2y"],
        dashboards:{},
       },function() {});

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

  function delayed(func_) {
    setTimeout(function() {
      return func_();
    },100);

  }
  function config(callback_) {
    delayed(function() {
      callback_(fixtures["config"]);
    });
  }

  function graph(graph_name_,callback_) {
    delayed(function() {
      var gr = fixtures["graph"];
      callback_(gr[graph_name_] || gr["event_processor_us;1d:2y"]);
    });
  }

  function key(key_,callback_) {
    delayed(function() {
      var all_keys = fixtures["key"];
      var k = $.map(all_keys,function(element,index) {return index});
      var rv = []
      if ( key_=="" ) { // no dots -> bring top level only
        $.each(k,function(idx,e) {
          if ( /^[\w-]+;/.test(e) )
            rv.push(e);
        });
      } else {
        var normalized_input = key_[key_.length-1]=='.' ? key_ : key_+".";
        var re = new RegExp("^" + key_+"[\\w;:-]*");
        $.each(k,function(idx,e) {
          if ( re.test(e) )
            rv.push(e);
        });
      }
      callback_(rv);
    });
  }

  function alerts(callback_) {
    delayed(function() {
      callback_(fixtures["alert"]);
    });
  }

  // if key == "persistent" the data is taken from the server, otherwise session storage
  // is used
  function load(user_,key_,callback_) {
    delayed(function() {
      if (key_=="persistent" ) {
        callback_($.localStorage.get(user_+".persistent"));
      } else {
        callback_($.sessionStorage.get(user_+"."+key_));
      }
    });
  }

  function save(user_,key_,data_,callback_) {
    delayed(function() {
      if (key_=="persistent" ) {
        $.localStorage.set(user_+".persistent",data_);
        if ( callback_ ) {
          callback_();
        }
        return;
      }
      $.sessionStorage.set(user_+"."+key_,data_);
      if ( callback_ ) {
        callback_();
      }
    });
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
