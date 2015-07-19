
function mule_mockup () {
  var fixtures_scripts = ["config","key","graph","piechart","alert"];
  var fixtures = {};
  const user = "Shmul the mule";
  ns=$.initNamespaceStorage('mule: ');

  save(user,"recent",
       ["book.buses;1d:2y",
        "penninsala;1h:90d;5m:3d",
        "but;5m:3d"],function() {});
  var v = $.localStorage.get(user);
  if ( !v ) {
    save(user,"persistent",
         {favorites:["apparatus;1h:90d",
                     "penninsala.food;1h:90d",
                     "pac.jam;1d:2y"],
          dashboards:{},
         },function() {});
  }

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
    $.doTimeout(2,func_);
  }

  function config(callback_) {
    delayed(function() {
      callback_(fixtures["config"]);
    });
  }

  function graph(graph_name_,callback_) {
    delayed(function() {
      var gr = fixtures["graph"];
      callback_(gr[graph_name_] || gr["penninsala;1d:2y"]);
    });
  }

  function piechart(graph_name_,time_,callback_) {
    delayed(function() {
      var pc = fixtures["piechart"];
      callback_(pc);
    });
  }

  function key(key_,callback_,raw_) {
    delayed(function() {
      var all_keys = fixtures["key"];
      key_impl(all_keys,key_,callback_,raw_);
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
    config : config,
    graph : graph,
    piechart : piechart,
    key : key,
    alerts : alerts,
    load: load,
    save: save,
  }


};

function run_tests() {
  QUnit.config.hidepassed = true;
  $(".content-wrapper").prepend("<div id='qunit'></div>");
  QUnit.test("utility functions", function( assert ) {
    assert.equal(timeunit_to_seconds("5m"),300);
    assert.equal(timeunit_to_seconds("1y"),60*60*24*365);
    assert.equal(timeunit_to_seconds("1d"),60*60*24);
    assert.deepEqual(graph_split("beer.ale;1d:2y"),["beer.ale","1d","2y"]);
    assert.deepEqual(graph_split("wine.red;1h:90d"),["wine.red","1h","90d"]);

    generate_all_graphs("no.such.graph:1h:90d",
                        function(actual_){
                          assert.deepEqual(actual_,[]);
                        });
    generate_all_graphs("scotch.sql_single_malt;1h:90d",
                        function(actual_) {
                          assert.deepEqual(actual_,
                                           ["scotch.sql_single_malt;5m:3d",
                                            "scotch.sql_single_malt;1h:90d",
                                            "scotch.sql_single_malt;1d:2y"]);
                        });

    generate_all_graphs("snark.foo.bar;1h:90d",
                        function(actual_) {
                          assert.deepEqual(actual_,
                                           ["snark.foo.bar;1d:2y"]);
                        });

    generate_all_graphs("snark.foo.bar;60d:90y",
                        function(actual_) {
                          assert.deepEqual(actual_,
                                           ["snark.foo.bar;1h:90d","snark.foo.bar;1d:2y"]);
                        });
    assert.equal(graph_refresh_time("snark.foo.bar;1h:90d"),3600);
    assert.equal(graph_refresh_time("scotch.sql_single_malt;5m:3d"),300);
  });

  scent_ds.key("beer",function(actual_) {
    QUnit.test("key 1", function( assert ) {
      assert.deepEqual(actual_,[
        "beer.ale",
        "beer.pilsner",
        "beer.stout",
        "beer;1d:2y",
        "beer;1h:90d",
        "beer;5m:3d"]);
    });
  });
  scent_ds.key("beer.",function(actual_) {
    QUnit.test("key 2", function( assert ) {
      assert.deepEqual(actual_,[
        "beer",
        "beer.ale",
        "beer.pilsner",
        "beer.stout"
      ]);
    });
  });
}
