function app() {
  var user = "Shmul the mule";
  var router = new Grapnel();
  var notified_graphs = {};
  var stack_bar_bottom = {"dir1": "up", "dir2": "left", "spacing1": 2, "spacing2": 2};
  var dashboards = {};

  // from Rickshaw
  function formatKMBT(y,dec) {
    var abs_y = Math.abs(y);
	if (abs_y >= 1000000000000)   { return (y / 1000000000000).toFixed(dec) + "T"; }
    if (abs_y >= 1000000000) { return (y / 1000000000).toFixed(dec) + "B"; }
    if (abs_y >= 1000000)    { return (y / 1000000).toFixed(dec) + "M"; }
    if (abs_y >= 1000)       { return (y / 1000).toFixed(dec) + "K"; }
    if (abs_y < 1 && y > 0)  { return y.toFixed(dec)+""; }
    if (abs_y === 0)         { return "0" }
    return y.toFixed(dec)+"";
  };

  function flot_axis_format(y,axis) {
    var label,dec = axis.tickDecimals;
    var exists;

    // a kludge around flot's original tick formatting implementation to avoid 2 things:
    // 1) not to have multiple ticks that due to our special formatting are the same, for example 1.6M and 1.8M both
    //   changed to 2M
    // 2) to make sure there is a consistency in the number of digits past decimal point being used.

    do {
      label = formatKMBT(y,dec);
      ++dec;
      // we scan back to see whether the label was already used
      exists = false;
      for (var j in axis.ticks ) {
        exists = exists || label==axis.ticks[j].label;
      }
    } while ( exists );

    // this may be redundant if the ticks are already properly formatted (as specified above), but to avoid
    // ugly checks, we do it anyway.
    for (var j in axis.ticks ) {
      var modified_label = formatKMBT(axis.ticks[j].v,dec);
      if ( !modified_label || modified_label.indexOf(".")==-1 ) {
        continue;
      }
      modified_label = modified_label.replace(/\.?0+([TBMK]?)$/,"$1");
      axis.ticks[j].label = modified_label;
    }
    return label;
  };

  function formatBase1024KMGTP(y) {
    var abs_y = Math.abs(y);
    var dec = 1;
    if (abs_y >= 1125899906842624)  { return (y / 1125899906842624).toFixed(dec) + "P" }
    if (abs_y >= 1099511627776){ return (y / 1099511627776).toFixed(dec) + "T" }
    if (abs_y >= 1073741824)   { return (y / 1073741824).toFixed(dec) + "G" }
    if (abs_y >= 1048576)      { return (y / 1048576).toFixed(dec) + "M" }
    if (abs_y >= 1024)         { return (y / 1024).toFixed(dec) + "K" }
    if (abs_y < 1 && y > 0)    { return y.toFixed(2) }
    if (abs_y === 0)           { return '' }
    return y;
  };


  function formatNumber(num_) {
    var parts = num_.toString().split(".");
    var n = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g,",");
    if ( parts.length==1 )
      return n;
    return [n,parts[1]].join(".");
  }

  // from https://github.com/Olical/binary-search
  // assume the data is a sorted array of [datetime,value] as flots requires; we are looking for the datetime value
  // modified to return the largest item less then or equal to x
  function binarySearch(data, x) {
    var min = 0;
    var max = data.length - 1;
    var guess,dx;

    while (min <= max) {
      guess = Math.floor((min + max) / 2);
      dx = data[guess][0];

      if (dx === x) {
        return guess;
      }
      else {
        if (dx < x) {
          min = guess + 1;
        }
        else {
          max = guess - 1;
        }
      }
    }

    return Math.min(min,data.length - 1);
  }

  function time_format(t_) {
    return $.plot.formatDate(t_,"%H:%M (%y-%m-%d)");//"%y-%m-%dT%H:%M");
  }

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

  function alert_to_css(alert_string_) {
    switch ( alert_string_ ) {
      case "CRITICAL LOW": return "crit-low";
      case "CRITICAL HIGH": return "crit-high";
      case "WARNING LOW": return "warn-low";
      case "WARNING HIGH": return "warn-high";
      case "anomaly": return alert_string_;
      case "stale": return alert_string_;
      case "NORMAL": return "ok-green";
    }
    return -1;
  }

  const lookup = {
    0: { title: "Critical", type: "critical", indicator: "danger", color: "red"},
    1: { title: "Warning", type: "warning", indicator: "warning", color: "orange"},
    2: { title: "Anomaly", type: "anomaly", indicator: "info", color: "anomaly"},
    3: { title: "Stale", type: "stale", indicator: "info", color: "purple"},
    4: { title: "Normal", type: "normal", indicator: "success", color: "green"},

    critical: 0,
    warning: 1,
    anomaly: 2,
    stale: 3,
    normal: 4
  }

  function background_color(selector_) {
    return $(selector_+':eq(0)').css('backgroundColor');
  }

  function alert_category(alert_) {
    if ( !lookup[0].hex_color ) {
      for (var i in lookup) {
        lookup[i].hex_color = background_color('.'+lookup[i].color);
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
    if ( alert_[7].indexOf("stale")>-1 )
      return "STALE";
    return null;
  }

  function mule_config(graph_,callback_) {
    scent_ds.config(graph_,function(conf_) {
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
    mule_config(graph_,function(conf_) {
      var gs = graph_split(graph_);
      var retentions = conf_[gs[0]] && conf_[gs[0]].retentions ? conf_[gs[0]].retentions : null;
      if ( !retentions ) { return callback_(); }

      if ( !gs || gs.length==0 ) { return callback_(); }
      var graph_rp = gs[1]+":"+gs[2];
      var selected_index = retentions.findIndex(function(rp) { return rp==graph_rp; } );
      if ( selected_index==-1 ) { return callback_(); }
      var c = [];
      for (var j=0; j<retentions.length; ++j) {
        if ( retentions[j]!="1s:1s") {
          c.push(gs[0]+";" + retentions[j]);
        }
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
    var box_body = ($(graph_container).find(".box-body"))[0];
    $(graph_container).attr("data-graph",template_data[0].graph);
    $(box_body).append($.templates("#graph-box-footer-template").render(template_data));
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

      // TODO - use the expected value of the anomaly as well (requires a change in mulelib:fdi)
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
        var dt = $("#alert-"+tr.type).dataTable(
          {
            bRetrieve: true,
          //      sDom: "trflp", // Show the record count select box *below* the table
          iDisplayLength: 15,
          aLengthMenu: [ 15, 30, 60 ],
          destroy: true,
          order: [[ 2, "desc" ]]

          });

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

    load_recent(function(recent_) {
      load_graphs_lists("#recent-container","#recent-template",recent_);
    });

    load_persistent(function(persistent_) {
      load_graphs_lists("#favorite-container","#favorite-template",persistent_.favorites);
    });
    var template_data = [{class: "",//"sidebar-form",
                          form_id: "topnav-search-form",
                          input_id: "search-keys-input"
    }];
    $("#topnav-search-container").empty().html($.templates("#search-form-template").render(template_data));
  }


  function setup_dashboards() {
    // TODO do we need to build this mapping all the time or can we do it every couple of secs
    // or upon demand?
    var new_dashboards = {};
    new_dashboards.static = scent_config().static_dashboards;

    scent_config().auto_dashboards(scent_ds,function(autos_) {
      new_dashboards.auto = autos_;
    });


    function populate_tree(src_node_,dest_node_,path_) {
      if ( $.type(src_node_)!="object" ) {
        return;
        }
      $.each(src_node_,function(k,v) {
        var new_node = { text: k, path: (path_.length>0 ? [path_,".",k].join("") : k) };
        if ( $.type(v)=="array") {
          new_node.dashboard = v;
          new_node.href = "#dashboard/"+new_node.path;
        } else {
          new_node.nodes = [];
          populate_tree(v,new_node.nodes,new_node.path);
        }
        dest_node_.push(new_node);
      });
    }

    $.doTimeout(100,function() {

      if ( !new_dashboards.auto ) {
        return true;
      }
      var tree = [];
      populate_tree(new_dashboards,tree,"");
      function force_link_color() {
        // the tree widget forces a style we want to override
        $("#main-dashboards-container").find("a[href!='#']").removeAttr("style");
      }

      $("#main-dashboards-container").treeview({data: tree,
                                                enableLinks: true,
      });
      force_link_color(); // TODO - this disappears when the tree is redrawn
      dashboards = new_dashboards;
      return false;
    });

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

  function show_piechart(name_, date_, dt_, value_) {
    if ( $(".modal-content").is(":visible") ) {
      // prevents showing the piechart twice
      return;
    }
    console.log("show_piechart: %s | %s | %d | %d", name_, date_.toString(), dt_, value_);

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
      if ( sorted_data.length>0 ) {
        for (var i in sorted_data) {
          sorted_data[i].precentage = (100*sorted_data[i].value/sum).toPrecision(3);
        }
      } else
      sorted_data.push({ graph: "No data to present"});

      var content = $.templates("#piechart-container-template").render([{}]);
      $(".bootbox-body").html(content);

      $.doTimeout(500,function() {
        $("#piechart-container").append($.templates("#piechart-template").render(sorted_data));
        $("#piechart-container a").click(function(e) {
          bootbox.hideAll();
          return true;
        });
        $('.sparkline-bullet').sparkline('html',{type: 'bullet', targetColor: 'black',width: "100%"});
      });
    }

    bootbox.dialog({
      title: name_ + " @ " + time_format(date_),
      message: "content",
      size: 'large'
    });

    scent_ds.piechart(name_,dt_,callback);
  }

  function choose_timestamp_format(name_) {
    var step = graph_step_in_seconds(name_);
    if ( step<TIME_UNITS.d ) {
      return "%e %b<br>%H:%M";
    }
    if ( step<TIME_UNITS.w ) {
      return "%e %b";
    }
    return "%e %b %y";
  }

  function choose_tick_size(name_) {
    var step = graph_step_in_seconds(name_);
    if ( step<TIME_UNITS.d ) {
      return [1,"hour"];
    }
    if ( step<TIME_UNITS.w ) {
      return [7,"day"];
    }
    return [1,"month"];
  }

  function is_graph_zoomed(graph_container_) {
    return $(graph_container_).hasClass("flot-zoomed");
  }

  function draw_graph(name_,data_,from_percent_,to_percent_,thresholds_,anomalies_,target_,alert_name_) {
    /*
       if ($(target_).hasClass("tall-graph")) {
       var use_small_fonts = false;
       var x_axis_ticks_count = 10;
       } else {
       var use_small_fonts = true;
       var x_axis_ticks_count = 5;
       }
     */
    var plot_data = [{
      label: graph_split(name_)[0],
      data: data_,
      color: background_color('.'+alert_to_css(alert_name_))
    }];
    var tooltip_data;
    var plot_options = {
      xaxis: {
        mode: "time",
        timeformat: choose_timestamp_format(name_),
        minTickSize: choose_tick_size(name_)
      },
      yaxis: {
        tickFormatter: flot_axis_format
      },
      legend: {
        show: true,
        labelFormatter: function(label, series) {
          if ( series.label.indexOf("crit")>-1 || series.label.indexOf("warn")>-1 ) {
            return series.label+" "+series.data[0][1];
          }
          if ( series.label=="Anomalies" ) {
            return series.label;
          }
        },
      },
      selection: {
		mode: "x"
	  },
      crosshair: {
		mode: "x" //TODO - change the color
	  },
      grid: {
		hoverable: true,
		autoHighlight: true,
	  },
      series: {
		lines: {
		  show: true,
		},
	  },
    };

    if ( thresholds_.length>0 ) {
      var xmin = data_[0][0],
          xmax = data_[data_.length-1][0],
          reveresed = thresholds_.reverse();
      // generate a line for each
      for (var i in reveresed) {
        plot_data.push({
          label: reveresed[i].label,
          color: background_color('.'+reveresed[i].label),
          data: [[xmin,reveresed[i].value],[xmax,reveresed[i].value]]
        });
      }
    }

    for (var i in anomalies_) {
      plot_data.push({
        label: "Anomalies",
        data: anomalies_[i],
        points: { show: true, radius: 8},
        lines: { show: false }
      });
    }

    function plot_it() {
      $.doTimeout(2,function() {
        $(target_).removeClass("flot-zoomed");
        // if it is the first time, we call plot, otherwise, we'll call setData and draw t
        if ( !$(target_).data("plot") ) {
          $(target_).data("plot",$.plot(target_,plot_data,plot_options));
        } else {
          var pl = $(target_).data("plot");
          pl.setData(plot_data);
          pl.draw();
        }
      });
    }

    plot_it();
    $(target_).bind("plotselected", function (event, ranges) {
	  // do the zooming
      var ymax = -1;
      var plot = $(target_).data("plot");

	  $.each(plot.getXAxes(), function(j, axis) {
		axis.options.min = ranges.xaxis.from;
		axis.options.max = ranges.xaxis.to;
        var dataset = plot_data[j].data;
        // we calculate the max value so we can change the yaxis
        var idx_min = binarySearch(dataset,axis.options.min),
            idx_max = binarySearch(dataset,axis.options.max);
        for (var i=idx_min; i<=idx_max; ++i) {
          ymax = Math.max(ymax,dataset[i][1]);
        }
      });
	  $.each(plot.getYAxes(), function(_, axis) {
		axis.options.max = ymax;
      });
	  plot.setupGrid();
	  plot.draw();
	  plot.clearSelection();

      // we add an artificial class to the container so an observer (like the auto refresh code) can check
      // whether the graph is zoomed.
      $(target_).addClass("flot-zoomed");
	});

    $(target_).unbind("dblclick"); // clear previous listeners
    $(target_).bind("dblclick",function (e) {
      //console.log("dblclick",is_graph_zoomed(target_));
      if ( is_graph_zoomed(target_) ) { // if the graph is in zoomed state, redraw it
        plot = plot_it();
      } else {
        show_piechart(name_, new Date(tooltip_data.x), tooltip_data.x/1000, tooltip_data.v);
      }
      e.stopPropagation();
    });

    var legends = $("#placeholder .legendLabel");

    $(target_).bind("plothover",  function (event, pos, item) {
      if ( !$(target_).data("plot") ) {
        //console.log("no plot found");
        return;
      }
      var dataset = $(target_).data("plot").getData()[0].data; // we are always interested in the graph data which is at the first index
      var idx = binarySearch(dataset,pos.x);
      if ( !idx || !dataset[idx] )
        return;
      tooltip_data = {
        x: dataset[idx][0],
        dt: $.plot.formatDate(new Date(dataset[idx][0]),"%H:%M (%y-%m-%d)"),
        v: dataset[idx][1]
      }
      $("#graph-tooltip").html(formatNumber(tooltip_data.v)+" @ "+tooltip_data.dt).css({top: pos.pageY+5, left: pos.pageX+5}).fadeIn(200);
	});

    $(target_).bind("mouseleave",  function (e) {
      $("#graph-tooltip").fadeOut(200);
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
      //title: title_,
      text: title_+": "+text_,
      type: 'notice',
      styling: 'fontawesome',
      addclass: "stack-bar-bottom",
      //cornerclass: "",
      width: "70%",
      stack: stack_bar_bottom,
      delay: 1500,
/*
      width: "390px",
      before_open: function(PNotify) {
        PNotify.get().css(get_center_pos(PNotify.get().width()));
      },
*/
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
        //remove_spinner(target_);
        return;
      }

      scent_ds.alerts(function(alerts_) {
        var data = new Array();
        for (var rw in raw_data_) {
          var dt = raw_data_[rw][2];
          var v = raw_data_[rw][0];
          if ( dt>100000 ) {
            data.push([dt * 1000,v]);
          }
        };
        data.sort(function(a,b) { return a[0]-b[0]});
        //data = fill_in_missing_slots(name_, data)
        //add_bounds(data);
        var graph_alerts = alerts_[name_];
        var thresholds = [];
        var alert_name = "NORMAL";
        if ( graph_alerts ) {
          thresholds = [
            { value: graph_alerts[0],
              label: "crit-low" },
            { value: graph_alerts[1],
              label: "warn-low" },
            { value: graph_alerts[2],
              label: "warn-high" },
            { value: graph_alerts[3],
              label: "crit-high" },
          ];
          // the thresholds should be adjusted to the displayed graph
          var step = graph_step_in_seconds(name_);
          var factor = graph_alerts[4]/step;
          for (var i=0; i<4; ++i) {
            thresholds[i].value = Math.round(thresholds[i].value/factor);
          }
          alert_name = graph_alerts[7];
        }
        var anomalies = [];
        if ( alerts_.anomalies && alerts_.anomalies[name_] ) {
          var dt = [];
          var anomaly = alerts_.anomalies[name_];
          for (var i in anomaly) {
            var x = anomaly[i]*1000;
            var idx = binarySearch(data,x);
            if ( idx && data[idx] ) {
              dt.push([data[idx][0],data[idx][1]]);
            }
          }
          anomalies.push(dt);
          alert_name = "anomaly";
        }
        var from_percent = 0;
        var to_percent = 100;
        draw_graph(name_,data,from_percent,to_percent,thresholds,anomalies,target_,alert_name);

        //remove_spinner(target_);
      });

    }
    //add_spinner(target_);

    scent_ds.graph(name_,callback);
  }

  function setup_charts(dashboard_name) {
    // perhaps we need to wait for the dashboards to be loaded
    if ( $.isEmptyObject(dashboards) ) {
      $.doTimeout(100,function() {
        if (!$.isEmptyObject(dashboards) ) {
          setup_charts(dashboard_name);
          return false;
        }
        return true;
      });
      return;
    }
    var dashboard = deep_key(dashboards,dashboard_name);
    if ( !dashboard ) {
      notify('Rrrr. Something went wrong','Can\'t find dashboard "'+dashboard_name+'".');
      return;
    }

    $("#charts-container").html("");
    var charts_per_row = scent_config().charts_per_row;
    var chart_width = Math.ceil(12/charts_per_row);
    var current_row;

    for (var i in dashboard) {
      var name = dashboard[i];
      if ( (i % charts_per_row)==0 ) {
        current_row = $('<div class="row">');
        $("#charts-container").append(current_row);
      }
      current_row.append($.templates("#chart-graph-template").render([{index: i,name: name, width: chart_width}]));
    }

    for (var i in dashboard) {
      var name = dashboard[i];
      var id = "chart-"+i+"-container";
      $('#'+id).append($.templates("#graph-template").render([{klass: "small-graph"}]));
      load_graph(name,"#"+id+" .graph-body");
      setup_graph_header(name,"#"+id+" .graph-header",true,null,"small-graph");
    }


    $("#charts-title").text(dashboard_name);


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

          graph_box_header(graph_header_container_,
                           {klass: klass_,
                            type: "graph", title: metric, parts: metric_parts, graph: name_,
                            links: links,favorite: favorite, alerted: ac.text, color: ac.color,
                            full: !!inner_navigation_, remove: !!remove_callback_});
          if ( remove_callback_ ) {
            $(".graph-remove").unbind("click").click(remove_callback_);
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
    },true);

    push_graph_to_recent(name_);
  }

  function teardown_graph() {
    $("#graph-box").hide();
    $("#graph-box-container").empty();
  }

  function populate_keys_table(keys_,target_) {
    var unified = {};

    for (var i in keys_) {
      var k = graph_split(keys_[i]),
          key = keys_[i],
          rp = null;
      if ( k ) {
        key = k[0];
        rp = k[1]+":"+k[2];
      }
      if ( !unified[key] ) {
        unified[key] = [];
      }
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
//      sDom: "trflp", // Show the record count select box *below* the table
      aoColumns: [
        { bSortable: false },
        { bSearchable: false, bSortable: false }
      ],
      iDisplayLength: 10,
      aLengthMenu: [ 10, 20, 40 ],
      destroy: true,
      order: [[ 0, "asc" ]]
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
    $.doTimeout(scent_config().graphs_refersh_rate*1000,function() {
      $(".graph-body").each(function(idx_,obj_) {
        var container = ($(obj_).closest(".graph-container"))[0];
        var container_box = ($(container).closest(".box"))[0];
        if ( $(container_box).css("display")=="none" ) {
          return;
        }
        var graph_container_id = "#"+$(container).attr('id')+" .graph-body";
        if ( is_graph_zoomed(graph_container_id) ) {
          return;
        }
        var graph = $(container).attr("data-graph");

        if ( graph_split(graph) ) {
          load_graph(graph,graph_container_id);
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

  function setup_flot() {
    $("<div id='graph-tooltip'></div>").css({
	  position: "absolute",
	  display: "none",
	  border: "1px solid",
	  padding: "2px",
	  "background-color": "#ffffe0",
	  opacity: 0.90
	}).appendTo("body");
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
      setup_dashboards();
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
      teardown_alerts(); // we need to clear the displayed alert table/graph when navigating between alerts
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

  setup_flot();
}


$(app);
