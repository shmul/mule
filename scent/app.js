function app() {
  var user = "Shmul the mule";
  var router = new Grapnel();
  var notified_graphs = {};

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


  var time_format = d3.time.format.utc("%y-%m-%dT%H:%M");

  function graph_to_id(graph_) {
    return graph_.replace(/[;:]/g,"_");
  }

  const TIME_UNITS = {s:1, m:60, h:3600, d:3600*24, w:3600*24*7, y:3600*24*365};
  function timeunit_to_seconds(timeunit_) {
    var m = timeunit_.match(/^(\d+)(\w)$/);
    if ( !m[1] || !m[2] ) { return null; }
    var secs = TIME_UNITS[m[2]];
    var a = parseInt(m[1]);
    return a && secs ? secs*a : null;
  }

  function graph_split(graph_) {
    var m = graph_.match(/^([\w\[\]\.\-]+);(\d\w+):(\d\w+)$/);
    if ( !m || m.length!=4 ) { return null; }
    m.shift();
    return m;
  }

  function graph_step_in_seconds(graph_) {
    var gs = graph_split(graph_);
    if ( !gs ) { return null; }
    return timeunit_to_seconds(gs[1]);
  }

  function graph_span_in_seconds(graph_) {
    var gs = graph_split(graph_);
    if ( !gs ) { return null; }
    return timeunit_to_seconds(gs[2]);
  }

  function graph_time_range(graph_) {
    var step = graph_step_in_seconds(graph_);
    var span = graph_span_in_seconds(graph_);
    var now = Math.floor(new Date().getTime() / 1000);
    var end_time = now - (now % step); // Round now to whole 'step' units
    var start_time = end_time - span;
    return [start_time, end_time];
  }

  function alert_index(alert_string_) {
    switch ( alert_string_ ) {
    case "CRITICAL LOW":
    case "CRITICAL HIGH": return 0;
    case "WARNING LOW":
    case "WARNING HIGH": return 1;
    case "anomaly": return 2;
    case "stale": return 3;
    case "NORMAL": return 4;
    }
    return -1;
  }

  const lookup = {
    0: { title: "Critical", type: "critical", indicator: "danger", color: "red"},
    1: { title: "Warning", type: "warning", indicator: "warning", color: "orange"},
    2: { title: "Anomaly", type: "anomaly", indicator: "info", color: "olive"},
    3: { title: "Stale", type: "stale", indicator: "info", color: "purple"},
    4: { title: "Normal", type: "normal", indicator: "success", color: "green"},

    critical: 0,
    warning: 1,
    anomaly: 2,
    stale: 3,
    normal: 4
  }
  function alert_category(alert_) {
    if ( !lookup[0].hex_color ) {
      for (var i in lookup) {
        lookup[i].hex_color = $('.bg-'+lookup[i].color+':eq(0)').css('backgroundColor')
        ++i;
      }
    }
    return lookup[alert_];
  }

  function alert_high_low(alert_) {
    if ( alert_[7].indexOf("HIGH")>-1 )
      return "HIGH";
    if ( alert_[7].indexOf("LOW")>-1 )
      return "LOW";
    return null;
  }

  function mule_config(callback_) {
    scent_ds.config(function(conf_) {
      callback_(jQuery.extend(true,{},conf_));
    });
  }

  function load_persistent(callback_) {
    scent_ds.load(user,"persistent",function(persistent_) {
      if ( !persistent_ ) {
        persistent_ = { dashboards: {},
                        favorites: [] };
      }
      callback_(persistent_);
    });
  }

  function load_recent(callback_) {
    scent_ds.load(user,"recent",function(recent_) {
      if ( !recent_ ) {
        recent_ = [];
      }
      callback_(recent_);
    });
  }

  function generate_all_graphs(graph_,callback_) {
    mule_config(function(conf_) {
      var m = graph_.match(/^([\w\-]+)(\.|;)/);
      if ( !m || !m[1] ) { return callback_(); }
      var c = conf_[m[1]];
      if ( !c ) { return callback_(); }
      var gs = graph_split(graph_);
      if ( !gs || gs.length==0 ) { return callback_(); }
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
  /*
    search form - common to all, with variations
    box header - specific to box type
    graph box header - common to all
    graph content - common to all, with variations in graph layout
    alert box - common to all alerts
    charts - specific header, embeds common graphs

  */

  // --- application functions
  function graph_box_header(container_,options_) {
    var template_data = [{}];
    jQuery.extend(template_data[0],options_);
    if ( options_.add_callback ) {
      template_data[0].add = true;
    }
    if ( options_.favorite ) {
      template_data[0].favorite = options_.favorite;
    }
    if ( options_.close ) {
      template_data[0].close = true;
    }
    if ( options_.full ) {
      template_data[0].full = true;
    }
    $(container_).html($.templates("#graph-box-header-template").render(template_data));
    var graph_container = ($(container_).closest(".graph-container"))[0];
    $(graph_container).attr("data-graph",template_data[0].graph);
  }

  function setup_menu_alerts() {
    var template_data = [];
    for (var i=0; i<5; ++i) {
      template_data.push(alert_category(i));
    }
    $("#alerts-menu-container").html($.templates("#alerts-menu-template").render(template_data));
  }

  function update_alerts(category_to_show_) {
    scent_ds.alerts(function(raw_data_) {

      // 0-critical, 1-warning, 2-anomaly, 3-Stale, 4-Normal

      var alerts = [[],[],[],[],[]];
      for (n in raw_data_) {
        var current = raw_data_[n];
        var idx = alert_index(current[7]);
        if ( idx>=0 ) {
          alerts[idx].push([n,current]);
        }
      }
      var anomalies = raw_data_["anomalies"];
      for (n in anomalies) {
        alerts[2].push([n,anomalies[n]]);
      }

      var template_data = [];
      var category_idx = alert_category(category_to_show_);
      for (var i=0; i<5; ++i) {
        var len = alerts[i].length;
        var tr = alert_category(i);
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
              time : time_format(new Date(cur[0]*1000)),
              type : "anomaly" // this is needed for jsrender's predicate in the loop
            });
          } else {
            var cur = alerts[i][j][1];
            d.push({
              graph : alerts[i][j][0],
              time : time_format(new Date(cur[8]*1000)),
              value : cur[6],
              period : cur[4],
              stale : cur[5],
              state : alert_high_low(cur),
            });
          }
        }
        template_data.push({title:tr.title,type:tr.type,records:d});
      }

      function set_click_behavior() {
        $(".alert-graph-name").click(function(e) {
          var graph = $(e.target).attr("data-target");
          $("#alert-graph-container").html($.templates("#graph-template").render([{klass: "tall-graph"}]));
          $("#alert-graph-container").attr("data-graph",graph);
          load_graph(graph,".graph-body");
          setup_graph_header(graph,".graph-header",true,null,"medium-graph");

          e.stopPropagation();
        });
      }

      var tr = alert_category(category_idx);
      if ( tr ) {
        $("#alert-box").show();
        $("#alert-table-container").empty().html($.templates("#alert-table-template").render(template_data));
        var dt = $("#alert-"+tr.type).dataTable({iDisplayLength: 15,
                                                 aLengthMenu: [ 15, 30, 60 ],
                                                 order: [[ 2, "desc" ]]});
        set_click_behavior();
        dt.on('draw',set_click_behavior);
        $("#alert-title").text(tr.title);
      }
    });
  }

  function teardown_alerts() {
    $("#alert-box").hide();
    $("#alert-table-container").empty();
    $("#alert-graph-container").empty();
  }

  function load_graphs_lists(container_,template_,data_) {
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
    $(container_).empty().append($.templates(template_).render(template_data));
    //$("#"+list_name_+"-container").empty().append($.templates("#"+list_name_+"-template").render(template_data));
  }

  function setup_menus() {

    load_persistent(function(persistent_) {
      load_graphs_lists("#favorite-container","#favorite-template",persistent_.favorites);
      load_graphs_lists("#dashboard-container","#dashboard-template",persistent_.dashboards);

      $(".dashboard-delete").click(function(e) {
        var name = $(e.target).attr("data-target");
        bootbox.confirm("Are you sure you want to delete the dashboard '"+name+"' ?", function(result) {
          if ( result ) {
            delete_dashboard(name);
          }
        });
      });


    });

    $("#dashboard-form").submit(function(e) {
      var name = $("#dashboard-add").val();
      e.preventDefault();
      e.stopPropagation();
      load_persistent(function(persistent_) {
        if ( !persistent_.dashboards[name] ) {
          persistent_.dashboards[name] = [];
          scent_ds.save(user,"persistent",persistent_,function() {
            load_graphs_lists("#dashboard-container","#dashboard-template",persistent_.dashboards);
            router.navigate('dashboard/'+name);
          });
        }
        $("#dashboard-add").val('');
      });

      return false;
    });

    function delete_dashboard(name_) {
      load_persistent(function(persistent_) {
        if ( persistent_.dashboards[name_] ) {
          delete persistent_.dashboards[name_];
          scent_ds.save(user,"persistent",persistent_,function() {
            router.navigate('/');
          });
        }
      });
    }

    load_recent(function(recent_) {
      load_graphs_lists("#recent-container","#recent-template",recent_);
    });
    var template_data = [{class: "",//"sidebar-form",
                          form_id: "topnav-search-form",
                          input_id: "search-keys-input"
                         }];
    $("#topnav-search-container").empty().html($.templates("#search-form-template").render(template_data));
  }

  // Add a .smoothed_value property to each datum using Double-Exponential Smoothing.
  function add_double_exponential_smoothed(data_) {
    if ( data_.length<2 ) { // can happen with extra short graphs
      return;
    }
    var alpha = 0.6;
    var gamma = 0.5;
    var datum, prev_datum;
    var b;
    data_[0].smoothed_value = data_[0].value;
    for (var i = 1; i < data_.length; i++) {
      datum = data_[i];
      prev_datum = data_[i - 1];
      if (!b && datum.value && prev_datum.value) {
        b = datum.value - prev_datum.value;
      }
      if (prev_datum.smoothed_value) {
        datum.smoothed_value = alpha * datum.value + (1 - alpha) * (prev_datum.smoothed_value + b);
        b = gamma * (datum.smoothed_value - prev_datum.smoothed_value) + (1 - gamma) * b;
      } else {
        datum.smoothed_value = datum.value;
      }
    }
  }

  function add_interval_days(date_, days_) {
    var res = new Date(date_);
    res.setDate(res.getDate() + days_);
    return res;
  }

  // Add .upper and .lower properties to each datum. These are calculated by
  // looking at the smoothed value of a data point 7 days before that and
  // adding/subtracting 10%.
  function add_upper_and_lower_bounds(data_) {
    var compare_interval_days = 7;
    var border_ratio = 0.10; // 10% boundary from each side
    var len = data_.length
    var minimal_time_for_bounds = add_interval_days(data_[0].date, compare_interval_days);
    var i = 0;
    while (i<len && data_[i].date < minimal_time_for_bounds) {
      i++;
    }
    var compare_interval_data_points = i;

    for (var i = 0; i < len; i++) {
      if (i < compare_interval_data_points) {
        data_[i].upper = null;
        data_[i].lower = null;
      } else {
        var compare_datum = data_[i - compare_interval_data_points];
        if (compare_datum && compare_datum.smoothed_value) {
          data_[i].upper = compare_datum.smoothed_value * (1 + border_ratio);
          data_[i].lower = compare_datum.smoothed_value * (1 - border_ratio);
        } else {
          data_[i].upper = null;
          data_[i].lower = null;
        }
      }
    }
  }

  function add_bounds(data_) {
    add_double_exponential_smoothed(data_);
    add_upper_and_lower_bounds(data_);
  }

  function on_graph_point_click(name_, date_, dt_, value_) {
    console.log("on_graph_point_click: %s | %s | %d | %d", name_, date_.toString(), dt_, value_);

    function callback(raw_data_) {
      if ( !raw_data_ || raw_data_.length==0 ) {
        notify('Unable to load chart','No data for "'+name_+'".');
        return;
      }
      var sorted_data = [];
      var sum = 0;
      $.each(raw_data_,function(name,value) {
        if ( value[0] && name!=name_ ) {
          var metric = graph_split(name);
          sorted_data.push({name: name,graph: metric[0],value: value[0][0]});
          sum += value[0][0];
        }
      });

      sorted_data.sort(function(a,b) { return b.value-a.value; });
      // the data is sorted in descending order. Each element is [name,value]
      var template_data = [];
      for (var i in sorted_data) {
        sorted_data[i].precentage = (100*sorted_data[i].value/sum).toPrecision(3);
      }
      var content = $.templates("#piechart-container-template").render([{}]);

      bootbox.dialog({
        title: name_ + " | " + time_format(date_),
        message: content,
        size: 'large'
      });

      $.doTimeout(500,function() {
        $("#piechart-container").append($.templates("#piechart-template").render(sorted_data));
        $("#piechart-container a").click(function(e) {
          bootbox.hideAll();
          return true;
        });
        $('.sparkline-bullet').sparkline('html',{type: 'bullet', targetColor: 'black',width: "100%"});
      });
    }

    scent_ds.piechart(name_,dt_,callback);
  }

  function draw_graph(name_,data_,from_percent_,to_percent_,baselines_,markers_,target_,alert_idx_) {
    var rollover_value_format = d3.format(",d");

    if ($(target_).hasClass("tall-graph")) {
      var use_small_fonts = false;
      var x_axis_ticks_count = 10;
    } else {
      var use_small_fonts = true;
      var x_axis_ticks_count = 5;
    }

    var graph_props = {
      data: data_,
      //title: graph_split(name_)[0],
      full_width: true,
      full_height: true,
      bottom: 40,
      area: false,
      xax_count: x_axis_ticks_count,
      x_extended_ticks: true,
      y_extended_ticks: true,
      target: target_,
      interpolate: "basic",
      show_confidence_band: ["lower", "upper"],
      baselines: baselines_,
      markers: markers_,
      small_text: use_small_fonts,
      brushing_interval: 1,
      mouseover: function(d, i) {
        d3.select(target_ + " svg .mg-active-datapoint")
          .text(rollover_value_format(d.value) + " @ "+time_format(d.date) );
      }
    };

    graph_props.color = alert_category(alert_idx_).hex_color;

    MG.data_graphic(graph_props);
    // Fix overlapping labels in x-axis
    d3.selectAll(target_ + " svg .mg-year-marker text").attr("transform", "translate(0, 8)");

    // .Use small fonts for baselines text, if needed
    d3.selectAll(target_ + " svg .mg-baselines").classed("mg-baselines-small", use_small_fonts);

    // Fix overlapping labels in baselines
    d3.selectAll(target_ + " svg .mg-baselines text").attr("dx", function (d,i) { return -i*60; });

    // Hook click events for the chart
    d3.selectAll(target_ + " svg .mg-rollover-rect rect")
      .on("dblclick", function (d,i) {
                     on_graph_point_click(name_, d.date, d.dt, d.value);
                   });
  }

  function remove_spinner(anchor_) {
    var box_body = $(anchor_).closest(".box-body")[0];
    $(box_body).find(".overlay").remove();
  }
  function add_spinner(anchor_) {
    var box_body = $(anchor_).closest(".box-body")[0];
    $(box_body).append('<div class="overlay"><i class="fa fa-refresh fa-spin"></i></div>');
  }

  function get_center_pos(width, top) {
    // top is empty when creating a new notification and is set when recentering
    if (!top) {
      top = 30;
      // this part is needed to avoid notification stacking on top of each other
      $('.ui-pnotify').each(function() {
        top += $(this).outerHeight() + 20;
      });
    }

    return {
      "top": top,
      "left": ($(window).width() / 2) - (width / 2)
    }
  }

  function notify(title_,text_) {
    new PNotify({
      title: title_,
      text: text_,
      type: 'notice',
      styling: 'fontawesome',
      width: "390px",
      delay: 3000,
      before_open: function(PNotify) {
        PNotify.get().css(get_center_pos(PNotify.get().width()));
      },
    });
  }

  function fill_in_missing_slots(graph_name_, actual_data_) {
    var step = graph_step_in_seconds(graph_name_);
    var time_range = graph_time_range(graph_name_);
    var first_time = time_range[0];
    var last_time = time_range[1];
    var full_data = new Array();
    var pos = 0;
    var t = first_time;
    while (t <= last_time) {
      if (actual_data_[pos] && t == actual_data_[pos].dt) {
        full_data.push(actual_data_[pos]);
        pos++;
        t += step;
      } else if (actual_data_[pos] && t > actual_data_[pos].dt) {
        full_data.push(actual_data_[pos]);
        pos++;
      } else {
        // No actual data for this time slot; push a "missing" entry (value=null)
        full_data.push({date: new Date(t * 1000), value: null, dt: t});
        t += step;
      }
    }
    return full_data;
  }

  function load_graph(name_,target_) {
    function callback(raw_data_) {
      if ( !raw_data_ || raw_data_.length==0 ) {
        if ( !notified_graphs[name_] ) {
          notify('Unable to load graph','No data for "'+name_+'".');
          notified_graphs[name_] = true;
        }
        remove_spinner(target_);
        return;
      }

      scent_ds.alerts(function(alerts_) {
        var data = new Array();
        for (var rw in raw_data_) {
          var dt = raw_data_[rw][2];
          var v = raw_data_[rw][0];
          if ( dt>100000 ) {
            data.push({date: new Date(dt * 1000), value: v, dt: dt});
          }
        };
        data.sort(function(a,b) { return a.dt-b.dt });
        data = fill_in_missing_slots(name_, data)
        add_bounds(data);
        var graph_alerts = alerts_[name_];
        var baselines = [];
        var alert_name = "NORMAL";
        if ( graph_alerts ) {
          baselines = [
            { value: graph_alerts[0],
              label: "crit-low" },
            { value: graph_alerts[1],
              label: "warn-low" },
            { value: graph_alerts[2],
              label: "warn-high" },
            { value: graph_alerts[3],
              label: "crit-high" },
          ];
          // the baselines should be adjusted to the displayed graph
          var step = graph_step_in_seconds(name_);
          var factor = graph_alerts[4]/step;
          for (var i=0; i<4; ++i) {
            baselines[i].value = baselines[i].value/factor;
          }
          alert_name = graph_alerts[7];
        }
        var markers = [];
        if ( alerts_.anomalies && alerts_.anomalies[name_] ) {
          var dt = alerts_.anomalies[name_][0];
          markers.push({
            date : new Date(dt * 1000),
            label: 'Anomaly'
          });
          alert_name = "anomaly";
        }
        var from_percent = 0;
        var to_percent = 100;
        draw_graph(name_,data,from_percent,to_percent,baselines,markers,target_,alert_index(alert_name));

        remove_spinner(target_);
      });

    }
    add_spinner(target_);
    $.doTimeout(30*1000,function() { remove_spinner(target_); }); // to make sure we get it off at some point
    scent_ds.graph(name_,callback);
  }

  function setup_charts(dashboard_name) {

    function add_to_dashboard(graph_) {
      load_persistent(function(persistent_) {
        var id = $("#charts-title").text().trim();
        var dashboard = persistent_.dashboards[id];
        if ( dashboard.indexOf(graph_)==-1 ) {
          dashboard.push(graph_);
          scent_ds.save(user,"persistent",persistent_);
          setup_charts(id);
        }
      });
    }

    function graph_remove_callback(e) {
      e.stopPropagation();
      var container = $(e.target).closest(".graph-container");
      var graph = $(container[0]).attr("data-graph");
      bootbox.confirm("Are you sure you want to remove the graph '"+graph+"' ?",
                      function(result) {
                        if ( result ) {
                          load_persistent(function(persistent_) {
                            var id = $("#charts-title").text().trim();
                            var idx = persistent_.dashboards[id].indexOf(graph);
                            if ( idx!=-1 ) {
                              persistent_.dashboards[id].splice(idx,1);
                              scent_ds.save(user,"persistent",persistent_,function() {
                                setup_charts(id);
                              });
                            }
                          });
                        }
                      });
    }

    load_persistent(function(persistent_) {
      var dashboard = persistent_.dashboards[dashboard_name];
      if ( !dashboard ) {
        notify('Rrrr. Something went wrong','Can\'t find dashboard "'+dashboard_name+'".');
        return;
      }
      $("#charts-container").html("");

      for (var i in dashboard) {
        var name = dashboard[i];
        $("#charts-container").append($.templates("#chart-graph-template").render([{index: i,
                                                                                    name: name}]));
      }

      for (var i in dashboard) {
        var name = dashboard[i];
        var id = "chart-"+i+"-container";
        $('#'+id).append($.templates("#graph-template").render([{klass: "small-graph"}]));
        load_graph(name,"#"+id+" .graph-body");
        setup_graph_header(name,"#"+id+" .graph-header",true,graph_remove_callback,"small-graph");
      }

    });

    $("#charts-title").text(dashboard_name);

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
                          add_to_dashboard(name_);
                        });
    });


    $("#charts-box").show();
  }

  function teardown_charts() {
    $("#charts-container").empty();
    $("#charts-box").hide();
  }

  function setup_search_keys(form_,input_,callback_) {
    $(form_).submit(function(e) {
      var name = $(input_).val();
      if ( !graph_split(name) ) {
        return false;
      }
      $(input_).blur();
      e.preventDefault();
      e.stopPropagation();
      if ( name.length>0 ) {
        // this is kind of ugly - the form reset generates another empty submit
        callback_(name);
      }
      $(form_).trigger("reset");
      return false;
    });
    var context = {};

    $(input_).typeahead({
      source :function (query,process) {
        var add_button = ($(input_).parent().find("[type=submit]"))[0];
        var original = $(add_button).html();
        //console.log('in source', query,context.scent_keys);

        function callback(keys_) {
          context.scent_keys = string_set_add_array(context.scent_keys || {},keys_);
          context.just_selected = false;
          $(add_button).html(original);
          //console.log('out source', context.scent_keys);
          process(string_set_keys(context.scent_keys));
        }

        context.query = query;
        scent_ds.key(query,callback);

        if ( !context.scent_keys || (query.length==0 && $(input_).val().length==0)) {
          $(add_button).html('<i class="fa fa-spinner"></i>');
          scent_ds.key("",callback);
        } else if ( context.just_selected || /[\.;]$/.test(context.query) ) {
          $(add_button).html('<i class="fa fa-spinner"></i>');
          scent_ds.key(query,callback);
        } else {
          return string_set_keys(context.scent_keys);
        }

      },

      afterSelect : function(query) {
        if ( !/;\d+\w:\d+\w$/.test(query) ) {
          //console.log('after select %s', query);
          var ths = this;
          $.doTimeout(2,function() {
            context.just_selected = true;
            ths.lookup();
          });
        }
      },

      minLength: 0,
      autoSelect: false,
      showHintOnFocus: true,
      items: 'all',
    });

  }

  function push_graph_to_recent(name_) {
    // update the recent list
    load_recent(function(recent_) {
      var idx = recent_.indexOf(name_);
      if ( idx!=-1 ) {
        recent_.splice(idx,1);
      }
      recent_.unshift(name_);
      recent_.length = Math.min(recent_.length,10);
      scent_ds.save(user,"recent",recent_);
    });
  }

  function setup_graph_header(name_,graph_header_container_,inner_navigation_,remove_callback_,klass_) {

    generate_all_graphs(name_,function(pairs_) {
      var links = [];
      for (var i in pairs_) {
        var rp = pairs_[i].match(/^[\w\.\-]+;(\d\w+:\d\w+)$/);
        var current = name_.indexOf(pairs_[i])!=-1;

        links.push({href: pairs_[i], rp: rp[1], current: current, inner_navigation: inner_navigation_});
      }

      load_persistent(function(persistent_) {
        var favorites = persistent_.favorites;
        var idx = favorites.indexOf(name_);
        var favorite = idx==-1 ? "fa-star-o" : "fa-star";
        var metric = graph_split(name_);

        scent_ds.alerts(function(alerts_) {
          var ac = {};
          if ( alerts_[name_] ) {
            var idx = alert_index(alerts_[name_][7]);
            if ( idx>=0 ) {
              ac = jQuery.extend(false,alert_category(idx));
              ac.text = alert_high_low(alerts_[name_]);
            }
          }

          if ( !metric ) {
            if ( !notified_graphs[name_] ) {
              notify('Rrrr. Something went wrong','Can\'t find such a metric "'+name_+'".');
              notified_graphs[name_] = true;
            }
            metric = [name_];
          }
          var suffix = [";",metric[1],":",metric[2]].join("");
          metric = metric[0];
          var metric_parts = metric.split(".");
          var accum = [];
          for (var i in metric_parts) {
            accum.push(metric_parts[i]);
            var title = (accum.length>1 ? "." : "") + metric_parts[i];
            metric_parts[i] = { href: accum.join(".")+suffix, title: title }
          }

          graph_box_header(graph_header_container_,{klass: klass_,
                                                    type: "graph", title: metric, parts: metric_parts, graph: name_,
                                                    links: links,favorite: favorite, alerted: ac.text, color: ac.color,
                                                    full: !!inner_navigation_, remove: !!remove_callback_});
          if ( remove_callback_ ) {
            $(".graph-remove").click(remove_callback_);
          }

          if ( notified_graphs[name_] ) {
            return;
          }

          $(".inner-navigation").click(function(e) {
            e.stopPropagation();
            var href = $(e.target).attr("data-graph"); // this is the graph to be shown
            var container = ($(e.target).closest(".graph-container"))[0];
            var graph = $(container).attr("data-graph"); // this is the existing graph
            var container_id = "#"+$(container).attr("id");
            var graph_view = $(container).find(".graph-view");
            console.log('inner navigation %s', graph);
            load_graph(href,container_id+" .graph-body");
            setup_graph_header(href,container_id+" .graph-header",true,remove_callback_,klass_);
            graph_view.parent().attr("href","#/graph/"+href);
          });


          $(".graph-favorite").click(function(e) {
            e.stopPropagation();
            var container = $(e.target).closest(".graph-container");
            var graph = $(container[0]).attr("data-graph");
            // we should re-read the persistent data
            load_persistent(function(persistent_) {
              var favorites = persistent_.favorites;
              var idx = favorites.indexOf(graph);
              console.log('favorite %s %s', graph, favorites);
              if ( idx==-1 ) { // we need to add to favorites
                favorites.push(graph);
                $(e.target).attr("class","graph-favorite fa fa-star");
              } else {
                favorites.splice(idx,1);
                $(e.target).attr("class","graph-favorire fa fa-star-o");
              }
              scent_ds.save(user,"persistent",persistent_,function() {
                setup_menus();
              });
            });
          });

        });

      });
    });
  }


  function setup_graph(name_) {
    $("#graph-box-container").html($.templates("#graph-template").render([{klass: "tall-graph"}]));
    load_graph(name_,"#graph-box .graph-body");
    setup_graph_header(name_,"#graph-box .graph-header",false,null,"tall-graph");
    $("#graph-box").show();
    var metric = graph_split(name_);
    scent_ds.key(metric[0],function(keys_) {
      populate_keys_table(keys_,"#graph-box-keys-container");
      populate_keys_list(keys_,"#keys-list",name_);
    },true);

    push_graph_to_recent(name_);
  }

  function teardown_graph() {
    $("#graph-box").hide();
  }

  // Populate the sidebar's keys list with one link per metric, all to the same
  // time span of the currently displayed graph.
  function populate_keys_list(keys_,target_, current_graph_name_) {
    var metric = graph_split(current_graph_name_);
    var suffix = [";",metric[1],":",metric[2]].join("");
    var graph_keys = [];
    var processed_keys = {};
    for (var i in keys_) {
      var k = graph_split(keys_[i]);
      if (!processed_keys[k[0]]) {
        var metric_parts = k[0].split(".");
        var last_part = metric_parts[metric_parts.length - 1];
        graph_keys.push({key: k[0], last_part: last_part, href: "#graph/"+k[0]+suffix});
        processed_keys[k[0]] = true;
      }
    }
    $(target_).empty().html($.templates("#keys-list-template").render({graph_keys: graph_keys}));
  }

  function populate_keys_table(keys_,target_) {
    var unified = {};
    for (var i in keys_) {
      var k = graph_split(keys_[i]);
      var key = k[0];
      if ( !unified[key] ) {
        unified[key] = [];
      }
      var rp = k[1]+":"+k[2];
      unified[key].push({href: keys_[i], rp: rp});
    }
    var records = [];
    for (var i in unified) {
      records.push({key: i, links: unified[i]});
    }


    function set_click_behavior() {
      $(".keys-table-key").click(function(e) {
        var key = $(e.target).attr("data-target");

        if ( key && key.length>0 ) {
          var metric_parts = key.split(".");
          var accum = [];
          for (var i in metric_parts) {
            accum.push(metric_parts[i]);
            var title = (accum.length>1 ? "." : "") + metric_parts[i];
            metric_parts[i] = { key: accum.join("."), title: title }
          }
          metric_parts.unshift({ key: "", title:"[root]&nbsp;"});
          $(target_+"-header").empty().html($.templates("#keys-table-header-template").render([{parts:metric_parts}]));
        } else
          $(target_+"-header").empty();

        scent_ds.key(key,function(keys_) {
          populate_keys_table(keys_,target_)
        },true);
        e.stopPropagation();
      });
    }

    $(target_).empty().html($.templates("#keys-table-template").render({records: records}));
    var dt = $("#keys-table").DataTable({
      bRetrieve: true,
      sDom: "frtilp", // Show the record count select box *below* the table
      aoColumns: [
        { sWidth: "25em" },
        { sWidth: "20em" }
      ],
      iDisplayLength: 10,
      aLengthMenu: [ 10, 20, 40 ],
      destroy: true,
      order: [[ 2, "desc" ]]
    });

    set_click_behavior();
    dt.on('draw',set_click_behavior);
  }

  function setup_main(key_) {
    var template_data = [{class: "",//"sidebar-form",
                          form_id: "main-search-form",
                          input_id: "main-search-keys-input"
                         }];
    $("#main-search-container").empty().html($.templates("#search-form-template").render(template_data));
    setup_search_keys("#main-search-form","#main-search-keys-input",
                      function(name_) {
                        router.navigate('graph/'+name_);
                      });
    load_persistent(function(persistent_) {
      load_graphs_lists("#main-favorite-container","#favorite-template",persistent_.favorites);
    });

    load_recent(function(recent_) {
      load_graphs_lists("#main-recent-container","#recent-template",recent_);
    });


    scent_ds.key(key_ || "",function(keys_) {
      populate_keys_table(keys_,"#main-keys-container")
    },true);

    $("#main-box").show();
  }

  function teardown_main() {
    $("#main-box").hide();
  }

  function set_title(title_) {
    $("title").text("Scent of a Mule | "+title_);
    //$("#page-title").text(title_);
    $("#qunit > a").text(title_);
  }

  function refresh_loaded_graphs() {
    notified_graphs = {}; // we reset the list of graphs on which we've already notified
    $.doTimeout(1000*60,function() {
      $(".graph-body").each(function(idx_,obj_) {
        var container = ($(obj_).closest(".graph-container"))[0];
        var container_box = ($(container).closest(".box"))[0];
        if ( $(container_box).css("display")=="none" ) {
          return;
        }
        var graph = $(container).attr("data-graph");

        // graphs in zoom state are also skipped
        if ( $(container).find(".mg-brushed").length>0 || $(container).find(".mg-brushing-in-progress").length>0 ) {
          //console.log('%s is in brushing. Not refreshing',graph);
          return;
        }

        if ( graph_split(graph) ) {
          load_graph(graph,"#"+$(container).attr('id')+" .graph-body");
          //console.log('refresh_loaded_graphs: %s',graph);
        }
      });
      return true;
    });

  }

  function setup_pnotify() {
    $(window).resize(function() {
      $(".ui-pnotify").each(function() {
        $(this).css(get_center_pos($(this).width(), $(this).position().top))
      });
    });
  }

  function setup_footer() {
    $("#scent-of-a-mule").click(function() {
      bootbox.dialog({
        title: "Phish | Scent of a Mule",
        message: '<iframe width="560" height="315" src="https://www.youtube.com/embed/qBkhao0DEhU" frameborder="0" allowfullscreen></iframe>'
      });
      return false;
    });

    $("#govt-mule").click(function() {
      bootbox.dialog({
        title: "Gov't Mule | What is Hip",
        message: '<iframe width="560" height="315" src="https://www.youtube.com/embed/lz29Fqbh3sE" frameborder="0" allowfullscreen></iframe>'
      });
      return false;
    });
  }

  function setup_router() {

    function globals() {
      setup_menus();
      setup_menu_alerts();
      setup_search_keys("#topnav-search-form","#search-keys-input",
                        function(name_) {
                          $("#topnav-search-dropdown").dropdown("toggle");
                          router.navigate('graph/'+name_);
                        });
      update_alerts(); // with no selected category it just updates the count
    }

    router.get(/^(index.html)?$/i, function(req) {
      set_title("");
      globals();
      setup_main(req.params[1]);
      teardown_alerts();
      teardown_charts();
      teardown_graph();
    });

    router.get('alert/:category', function(req) {
      set_title("Alert");
      var category = req.params.category;
      globals();
      teardown_main();
      teardown_charts();
      teardown_graph();
      update_alerts(category);
      refresh_loaded_graphs();
    });

    router.get('graph/:id', function(req) {
      set_title("Graph");
      globals();
      teardown_main();
      teardown_alerts();
      teardown_charts();
      var id = req.params.id;
      setup_graph(id);
      refresh_loaded_graphs();
    });

    router.get('dashboard/:id', function(req) {
      set_title("Dashboard");
      globals();
      var id = req.params.id;
      teardown_main();
      teardown_alerts();
      teardown_graph();
      setup_charts(id);
      refresh_loaded_graphs();
    });

    router.on('navigate', function(event){
      console.log('URL changed to %s', this.fragment.get());
    });
  }

  setup_footer();

  // call init functions
  setup_pnotify();

  setup_router();

}


$(app);
