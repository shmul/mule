function app() {
  var user = "Shmul the mule";
  var router = new Grapnel();

  // from Rickshaw
  function formatKMBT(y) {
    var abs_y = Math.abs(y);
	  if (abs_y >= 1000000000000)   { return (y / 1000000000000).toFixed(1) + "T" }
    if (abs_y >= 1000000000) { return (y / 1000000000).toFixed(1) + "B" }
    if (abs_y >= 1000000)    { return (y / 1000000).toFixed(1) + "M" }
    if (abs_y >= 1000)       { return (y / 1000).toFixed(1) + "K" }
    if (abs_y < 1 && y > 0)  { return y.toFixed(1) }
    if (abs_y === 0)         { return '' }
    return y;
  };

  function formatBase1024KMGTP(y) {
    var abs_y = Math.abs(y);
    if (abs_y >= 1125899906842624)  { return (y / 1125899906842624).toFixed(1) + "P" }
    if (abs_y >= 1099511627776){ return (y / 1099511627776).toFixed(1) + "T" }
    if (abs_y >= 1073741824)   { return (y / 1073741824).toFixed(1) + "G" }
    if (abs_y >= 1048576)      { return (y / 1048576).toFixed(1) + "M" }
    if (abs_y >= 1024)         { return (y / 1024).toFixed(1) + "K" }
    if (abs_y < 1 && y > 0)    { return y.toFixed(2) }
    if (abs_y === 0)           { return '' }
    return y;
  };


  const TIME_UNITS = {s:1, m:60, h:3600, d:3600*24, w:3600*24*7, y:3600*24*365};
  function timeunit_to_seconds(timeunit_) {
    var m = timeunit_.match(/^(\d+)(\w)$/);
    if ( !m[1] || !m[2] ) { return null; }
    var secs = TIME_UNITS[m[2]];
    var a = parseInt(m[1]);
    return a && secs ? secs*a : null;
  }

  function graph_split(graph_) {
    var m = graph_.match(/^([\w\.\-]+);(\d\w+):(\d\w+)$/);
    if ( !m || m.length!=4 ) { return null; }
    m.shift();
    return m;
  }

  function graph_step_in_seconds(graph_) {
    var gs = graph_split(graph_);
    if ( !gs ) { return null; }
    return timeunit_to_seconds(gs[1]);
  }
  function mule_config(callback_) {
    scent_ds.config(function(conf_) {
      callback_(jQuery.extend(true,{},conf_));
    });
  }

  function generate_all_graphs(graph_,callback_) {
    mule_config(function(conf_) {
      var m = graph_.match(/^([\w\-]+)(\.|;)/);
      if ( !m || !m[1] ) { callback_(); }
      var c = conf_[m[1]];
      if ( !c ) { callback_(); }
      var gs = graph_split(graph_);
      if ( !gs ) { callback_(); }
      var selected_index = c.indexOf(gs[1]+":"+gs[2]);
      for (var j=0; j<c.length; ++j) {
        c[j] = gs[0]+";"+c[j];
      }
      // sort based on step
      c.sort(function(a,b) {
        var step_a = a.match(/;(\d+\w+)/);
        var step_b = b.match(/;(\d+\w+)/);
        return timeunit_to_seconds(step_a[1])-timeunit_to_seconds(step_b[1]);
      });
      callback_(c,selected_index);
    });
  }

  function graph_refresh_time(graph_) {
    var gs = graph_split(graph_);
    if ( !gs) { return null; }
    return timeunit_to_seconds(gs[1]);
  }

  function string_set_add(set_,key_) {
    set_ = set_ || {};
    set_[key_] = true;
    return set_;
  }

  function string_set_add_array(set_,keys_) {
    set_ = set_ || {};
    $.each(keys_,function(idx,k) {
      set_[k] = true;
    });
    return set_;
  }

  function string_set_keys(set_) {
    return $.map(set_ || {},function(key_,idx_) { return idx_; });
  }

  // --- application functions
  function box_header(options_) {
    var template_data = [{name: ""+options_.type+"",
                          title: options_.title,
                          links: options_.links}];
    if ( options_.add_callback ) {
      template_data[0].add = true;
    }
    if ( options_.favorite ) {
      template_data[0].favorite = options_.favorite;
    }
    if ( options_.close ) {
      template_data[0].close = true;
    }

    $("#"+options_.type+"-box-header-container").html($.templates("#box-header-template").render(template_data));
    if ( options_.add_callback ) {
      $("#charts-add-modal").on('shown.bs.modal',function(e) {
        var template_data = [{class: "form",
                              form_id: "charts-search-form",
                              input_id: "charts-search-input",
                              add: true
                             }];
        $("#charts-add-modal-form-container").empty().append($.templates("#search-form-template").render(template_data));
        setup_search_keys("#charts-search-form","#charts-search-input",
                          function(name_) {
                            $("#charts-add-modal").modal('hide');
                            options_.add_callback(name_);
                          });
      });
    }

    if ( options_.delete_callback ) {

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

  function update_alerts(category_to_show_) {
    scent_ds.alerts(function(raw_data_) {

      // 0-critical, 1-warning, 2-anomaly, 3-Stale, 4-Normal
      const lookup = {
        0: { title: "Critical", type: "critical"},
        1: { title: "Warning", type: "warning"},
        2: { title: "Anomaly", type: "anomaly"},
        3: { title: "Stale", type: "stale"},
        4: { title: "Normal", type: "normal"},
        critical: 0,
        warning: 1,
        anomaly: 2,
        stale: 3,
        normal: 4
      }

      var date_format = d3.time.format("%Y-%M-%d:%H%M%S");
      var alerts = [[],[],[],[],[]];
      for (n in raw_data_) {
        var current = raw_data_[n];
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
      var anomalies = raw_data_["anomalies"];
      for (n in anomalies) {
        alerts[2].push([n,anomalies[n]]);
      }

      var template_data = [];
      var category_idx = lookup[category_to_show_];
      for (var i=0; i<5; ++i) {
        var len = alerts[i].length;
        var tr = lookup[i];
        $("#alert-menu-"+tr.type).text(len);
        if ( i!=category_idx ) {
          continue;
        }
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
              period : cur[4],
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

      function alert_graph_name_click(e) {
        var graph = $(e.target).attr("data-target");
        show_graph(graph,"#alert-graph-container","medium-graph",true);
        e.stopPropagation();
      }
      function set_click_behavior() {
        $(".alert-graph-name").click(alert_graph_name_click);
      }
      var tr = lookup[category_idx];
      if ( tr ) {
        $("#alert-container").empty();
        $("#alert-container").html($.templates("#alert-template").render(template_data));
        var dt = $("#alert-"+tr.type).dataTable({iDisplayLength: 10,order: [[ 2, "desc" ]]});
        set_click_behavior();
        dt.on('draw',set_click_behavior);
        box_header({type: "alert", title: tr.title});

        $(".alert-graph-name").click(alert_graph_name_click);
        $("#alert-box").show();
      }
    });
  }

  function teardown_alerts() {
    $("#alert-container").empty();
    $("#alert-box").hide();
  }

  function setup_menus() {

    function load_graphs_lists(list_name_,data_) {
      if ( !data_ ) { return; }
      var template_data = [];
      if ( Array.isArray(data_) ) {
        for (var d=0; d<data_.length; ++d) {
          template_data.push({idx:1+d, name:data_[d]});
        }
      } else {
        var i = 0;
        for (var d in data_) {
          ++i;
          template_data.push({idx:i, name:d});
        }
        template_data.sort(function(a,b) {
          return a.name.localeCompare(b.name);
        });
      }
      $("#"+list_name_+"-container").empty().append($.templates("#"+list_name_+"-template").render(template_data));
    }

    scent_ds.load(user,"persistent",function(persistent_) {
      load_graphs_lists("favorite",persistent_.favorites);
      load_graphs_lists("dashboard",persistent_.dashboards);
    });

    $("#dashboard-form").submit(function(e) {
      var name = $("#dashboard-add").val();
      e.preventDefault();
      e.stopPropagation();
      scent_ds.load(user,"persistent",function(persistent_) {
        if ( !persistent_.dashboards ) {
          persistent_.dashboards = {};
        }
        if ( !persistent_.dashboards[name] ) {
          persistent_.dashboards[name] = [];
          scent_ds.save(user,"persistent",persistent_,function() {
            load_graphs_lists("dashboard",persistent_.dashboards);
            router.navigate('dashboard/'+name);
          });
        }
        $("#dashboard-add").val('');
      });

      return false;
    });

    function delete_dashboard(name_) {
      scent_ds.load(user,"persistent",function(persistent_) {
        if ( persistent_.dashboards[name_] ) {
          delete persistent_.dashboards[name_];
          scent_ds.save(user,"persistent",persistent_,function() {
            router.navigate('/');
          });
        }
      });
    }


    $(".dashboard-delete").click(function(e) {
      var name = $(e.target).attr("data-target");
      bootbox.confirm("Are you sure you want to delete the dashboard '"+name+"' ?", function(result) {
        if ( result ) {
          options_.delete_callback(name);
        }
      });
    });

    scent_ds.load(user,"recent",function(recent_) {
      load_graphs_lists("recent",recent_);
    });
    var template_data = [{class: "sidebar-form",
                          form_id: "sidebar-search-form",
                          input_id: "search-keys-input"
                         }];
    $("#sidebar-search-container").html($.templates("#search-form-template").render(template_data));
  }

  function draw_graph(name_,data_,target_,with_focus_) {
    // TODO use with_focus_ to add zoom buttons
    var rollover_date_format = d3.time.format("%Y-%m-%d %H:%M");
    var rollover_value_format = d3.format(",d");

    var x_axis_ticks_count = ($(target_).hasClass("tall-graph")) ? 10 : 5;

    MG.data_graphic({
      data: data_,
      // TODO For some reason this breaks the chart:
      // missing_is_zero: true,
      full_width: true,
      full_height: true,
      bottom: 40,
      area: false,
      xax_count: x_axis_ticks_count,
      target: target_,
      interpolate: "basic",
      legend: [name_],
      legend_target: ".legend",
      mouseover: function(d, i) {
         d3.select(target_ + " svg .mg-active-datapoint")
           .text(rollover_date_format(d.date) + ": " + name_ + " " + rollover_value_format(d.value));
      }
    });
  }

  function load_graph(name_,target_,with_focus_) {
    function callback(raw_data_) {
      var data = new Array();
      for (var rw in raw_data_) {
        var dt = raw_data_[rw][2];
        var v = raw_data_[rw][0];
        if ( dt>100000 ) {
          data.push({date: new Date(dt * 1000), value: v});
        }
      };
      data.sort(function(a,b) { return a.date-b.date });

      draw_graph(name_,[data],target_,with_focus_);
    }
    scent_ds.graph(name_,callback);
  }



  function setup_charts(id) {
    $("#charts-container").empty();

    function add_to_dashboard(graph_) {
      scent_ds.load(user,"persistent",function(persistent_) {
        var id = $("#charts-title").text().trim();
        var dashboard = persistent_.dashboards[id];
        if ( dashboard.indexOf(graph_)==-1 ) {
          dashboard.push(graph_);
          scent_ds.save(user,"persistent",persistent_);
          setup_charts(id);
        }
      });
    }

    function remove_from_dashboard(graph_) {
      scent_ds.load(user,"persistent",function(persistent_) {
        var id = $("#charts-title").text().trim();
        var idx = persistent_.dashboards[id].indexOf(graph_);
        if ( idx!=-1 ) {
          persistent_.dashboards[id].splice(idx,1);
          scent_ds.save(user,"persistent",persistent_,function() {
            setup_charts(id);
          });
        }
      });
    }

    scent_ds.load(user,"persistent",function(persistent_) {
      var dashboard = persistent_.dashboards[id];
      if ( !dashboard ) {
        // TODO - flash an error and exit
        return;
      }

      var template = $.templates("#chart-template");
      var template_data = [];
      for (var i in dashboard) {
        template_data.push({idx: i,name:dashboard[i]});
      }
      var d = template.render(template_data)
      $("#charts-container").append(d);
      for (var i in dashboard) {
        load_graph(template_data[i].name,"#chart-"+i);
      }
      $(".chart-remove").click(function(e) {
        var graph = $(e.target).attr("data-target");
        bootbox.confirm("Are you sure you want to remove '"+graph+"' from the dashboard?", function(result) {
          if ( result ) {
            remove_from_dashboard(graph);
          }
        });
      });

      $(".chart-show-modal").click(function(e) {
        var graph = $(e.target).closest(".small-graph").attr("data-target");

        $('#modal-target').on('shown.bs.modal', function (e) {
          load_graph(graph,"#modal-graph",false);
        });

        // cleanup
        $('#modal-target').on('hidden.bs.modal', function (e) {
          $("#modal-graph").html("");
        });

        $("#modal-target").modal('show');
      });


      box_header({type: "charts",title: id,add_callback: add_to_dashboard});
      $("#charts-box").show();
/*
      $(".modal-wide").empty();
      $(".modal-wide").on("shown.bs.modal", function() {
        var height = $(window).height();
        $(this).find(".modal-body").css("max-height", height);
      });
*/
    });
  }

  function teardown_charts() {
    $("#charts-container").empty();
    $("#charts-box").hide();
  }

  function setup_search_keys(form_,input_,callback_) {
    $(form_).submit(function(e) {
      var name = $(input_).val();
      $(input_).blur();
      e.preventDefault();
      e.stopPropagation();
      if ( name.length>0 ) {
        // this is kind of ugly - the form reset generates another empty submit
        callback_(name);
      }
      $(form_).trigger("reset");
      //return false;
    });
    $(input_).typeahead({
      source:function (query,process) {
        function callback(keys_) {
          if ( !this.scent_keys ) {
            this.scent_keys = string_set_add_array({},keys_);
          } else if ( query[query.length-1]=='.') {
            string_set_add_array(this.scent_keys,keys_);
          }
          process(string_set_keys(this.scent_keys));
        }

        if ( !this.scent_keys ) {
          scent_ds.key("",callback);
        } else if ( query[query.length-1]=='.') {
          scent_ds.key(query,callback);
        }
      },
      minLength: 0,
      items: 'all',
    });

  }

  function show_graph(name_,graph_container_,graph_class_,inner_navigation_) {

    $(graph_container_).html($.templates("#graph-template").render([{klass: graph_class_}]));

    load_graph(name_,"#graph",false);

    // update the recent list
    scent_ds.load(user,"recent",function(recent_) {
      var idx = recent_.indexOf(name_);
      if ( idx!=-1 ) {
        recent_.splice(idx,1);
      }
      recent_.unshift(name_);
      recent_.length = Math.min(recent_.length,10);
      scent_ds.save(user,"recent",recent_);
      // we don't updated the recent list as it seems to mess with the sidebar search form
      // and it might very well wait for the next refresh
    });

    function set_header(pairs_) {
      var links = [];
      for (var i in pairs_) {
        var rp = pairs_[i].match(/^[\w\.\-]+;(\d\w+:\d\w+)$/);
        var current = name_.indexOf(pairs_[i])!=-1;
        links.push({href: pairs_[i], rp: rp[1], current: current, inner_navigation: inner_navigation_});
      }

      scent_ds.load(user,"persistent",function(persistent_) {
        var favorites = persistent_.favorites;
        var idx = favorites.indexOf(name_);
        var favorite = idx==-1 ? "fa-star-o" : "fa-star";
        var metric = graph_split(name_)[0];

        box_header({type: "graph", title: metric,
                    links: links,favorite: favorite});
        $(".inner-navigation").click(function(e) {
          var graph = $(e.target).attr("data-target");
          show_graph(graph,"#alert-graph-container","medium-graph",true);
        });

        $("#graph-favorite").click(function(e) {
          // we should re-read the persistent data
          scent_ds.load(user,"persistent",function(persistent_) {
            var favorites = persistent_.favorites;
            var idx = favorites.indexOf(name_);

            if ( idx==-1 ) { // we need to add to favorites
              favorites.push(name_);
              $(e.target).attr("class","fa fa-star");
            } else {
              favorites.splice(idx,1);
              $(e.target).attr("class","fa fa-star-o");
            }
            scent_ds.save(user,"persistent",persistent_,function() {
              setup_menus();
            });
          });
        });
      });
    }

    generate_all_graphs(name_,set_header);
  }

  function setup_graph(name_) {
    show_graph(name_,"#graph-container","tall-graph");
    $("#graph-box").show();
  }

  function teardown_graph() {
    $("#graph-box").hide();
  }

  function run_tests() {
    QUnit.config.hidepassed = true;
    $(".content-wrapper").prepend("<div id='qunit'></div>");
    QUnit.test("utility functions", function( assert ) {
      assert.equal(timeunit_to_seconds("5m"),300);
      assert.equal(timeunit_to_seconds("1y"),60*60*24*365);
      assert.equal(timeunit_to_seconds("1d"),60*60*24);
      assert.deepEqual(graph_split("brave.frontend;1d:2y"),["brave.frontend","1d","2y"]);
      assert.deepEqual(graph_split("event.buka_mr_result;1h:90d"),["event.buka_mr_result","1h","90d"]);
      generate_all_graphs("kashmir_report_db_storer.sql_queries;1h:90d",
                            function(actual_) {
                              assert.deepEqual(actual_,
                                               ["kashmir_report_db_storer.sql_queries;5m:3d",
                                                "kashmir_report_db_storer.sql_queries;1h:90d",
                                                "kashmir_report_db_storer.sql_queries;1d:2y"]);
                            });

      generate_all_graphs("malware_signature.foo.bar;1h:90d",
                          function(actual_) {
                            assert.deepEqual(actual_,
                                             ["malware_signature.foo.bar;1d:2y"]);
                          });

      generate_all_graphs("malware_signature.foo.bar;60d:90y",
                          function(actual_) {
                            assert.deepEqual(actual_,
                                             ["malware_signature.foo.bar;1h:90d","malware_signature.foo.bar;1d:2y"]);
                          });
      assert.equal(graph_refresh_time("malware_signature.foo.bar;1h:90d"),3600);
      assert.equal(graph_refresh_time("kashmir_report_db_storer.sql_queries;5m:3d"),300);
    });

    const expected = ["brave;1d:2y",
                      "brave;1h:90d",
                      "brave;5m:3d",
                      "brave.backend;1d:2y",
                      "brave.backend;1h:90d",
                      "brave.backend;5m:3d",
                      "brave.hrl_collect;1d:2y",
                      "brave.hrl_collect;1h:90d",
                      "brave.hrl_collect;5m:3d",
                      "brave.request;1d:2y",
                      "brave.request;1h:90d",
                      "brave.request;5m:3d",
                      "brave.frontend;1d:2y",
                      "brave.frontend;1h:90d",
                      "brave.frontend;5m:3d"];
    scent_ds.key("brave",function(actual_) {
      QUnit.test("key 1", function( assert ) {
        assert.deepEqual(actual_,expected);
      });
    });
    scent_ds.key("brave.",function(actual_) {
      QUnit.test("key 2", function( assert ) {
        assert.deepEqual(actual_,expected);
      });
    });
  }

  function set_title(title_) {
    $("title").text("Scent of a Mule | "+title_);
    //$("#page-title").text(title_);
    $("#qunit > a").text(title_);
  }

  function setup_router() {

    function globals() {
      setup_menus();
      setup_alerts_menu();
      setup_search_keys("#sidebar-search-form","#search-keys-input",
                        function(name_) {
                          router.navigate('graph/'+name_);
                        });
      update_alerts(); // with no selected category it just updates the count
    }

    router.get(/(index.html)?/, function(req) {
      set_title("");
      var category = req.params.category;
      globals();
      teardown_alerts();
      teardown_charts();
      teardown_graph();
    });

    router.get('alert/:category', function(req) {
      set_title("Alert");
      var category = req.params.category;
      globals();
      teardown_charts();
      teardown_graph();
      update_alerts(category);
    });

    router.get('graph/:id', function(req) {
      set_title("Graph");
      globals();
      teardown_alerts();
      teardown_charts();
      var id = req.params.id;
      setup_graph(id);
    });

    router.get('dashboard/:id', function(req) {
      set_title("Dashboard");
      globals();
      var id = req.params.id;
      teardown_alerts();
      teardown_graph();
      setup_charts(id);
    });

    router.on('navigate', function(event){
      console.log('URL changed to %s', this.fragment.get());
    });
  }


  // call init functions


//  run_tests();
  setup_router();

}


$(app);
