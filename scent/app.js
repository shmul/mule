function app() {
  var user = "Shmul the mule";
  var router = new Grapnel();
  var notified_graphs = {};
  var stack_bar_bottom = {"dir1": "up", "dir2": "left", "spacing1": 2, "spacing2": 2};
  const more_colors = ["#88AA99","#79B5F2","#ADC3D8","#115588","#2B2B2B","#001122"];
  //const more_colors = ["#457f3f", "#117788", "#3D4C44", "#88AA99", "#557777", "#2B2B2B"];
  const axis_font = {
    size: 11,
    lineHeight: 13,
    style: "italic",
    weight: "bold",
    family: "sans-serif",
    variant: "small-caps",
    color: "white"
  };


  var dashboards = {};

  function formatShowingRows(pageFrom, pageTo, totalRows) {
    return [pageFrom,"-",pageTo,"/",totalRows].join("");
  }

  function formatRecordsPerPage(pageNumber) {
    return "| # Rows "+pageNumber;
  }

  // from Rickshaw
  function formatKMBT(y,dec) {
    var abs_y = Math.abs(y);
	if (abs_y >= 1000000000000)   { return (y / 1000000000000).toFixed(dec) + "T"; }
    if (abs_y >= 1000000000) { return (y / 1000000000).toFixed(dec) + "G"; }
    if (abs_y >= 1000000)    { return (y / 1000000).toFixed(dec) + "M"; }
    if (abs_y >= 1000)       { return (y / 1000).toFixed(dec) + "K"; }
    if (abs_y < 1 && y > 0)  { return y.toFixed(dec)+""; }
    if (abs_y === 0)         { return "0" }
    return y.toFixed(dec)+"";
  };

  function formatTimestamp(secs,dec) {
    dec = dec || 1;
    if ( !dec || !secs ) { return ""; }
    const s=1, m=60, h=3600, d=3600*24, w=3600*24*7, y=3600*24*365;
    if ( secs>=y ) { return (secs/y).toFixed(0) + "y"+formatTimestamp(secs%y,--dec); }
    if ( secs>=w ) { return (secs/w).toFixed(0) + "w"+formatTimestamp(secs%w,--dec); }
    if ( secs>=d ) { return (secs/d).toFixed(0) + "d"+formatTimestamp(secs%d,--dec); }
    if ( secs>=h ) { return (secs/h).toFixed(0) + "h"+formatTimestamp(secs%h,--dec); }
    if ( secs>=m ) { return (secs/m).toFixed(0) + "m"+formatTimestamp(secs%m,--dec); }

    return Math.round(secs)+"s";
  }

  function flot_axis_format(y,axis,use_timestamp) {
    var label,dec = 0;
    var exists;
    var format_func = use_timestamp ? formatTimestamp : formatKMBT;

    // a kludge around flot's original tick formatting implementation to avoid 2 things:
    // 1) not to have multiple ticks that due to our special formatting are the same,
    //    for example 1.6M and 1.8M both changed to 2M
    // 2) to make sure there is a consistency in the number of digits
    //    past decimal point being used.

    /* if ( use_timestamp ) {
     *   return format_func(Math.round(y),0);
     * }
     */
    var dec = axis.tickDecimals;
    do {
      label = format_func(y,dec);
      // we scan back to see whether the label was already used
      exists = false;
      for (var j in axis.ticks ) {
        exists = exists || label==axis.ticks[j].label;
      }
      ++dec;
    } while ( exists );

    // this may be redundant if the ticks are already properly formatted (as specified above),
    //but to avoid ugly checks, we do it anyway.
    for (var j in axis.ticks ) {
      var modified_label = format_func(axis.ticks[j].v,dec);
      if ( !modified_label || modified_label.indexOf(".")==-1 ) {
        continue;
      }
      modified_label = modified_label.replace(/\.?0+([TGMKywdhms]?)$/,"$1");
      axis.ticks[j].label = modified_label;
    }

    return label;
  }

  function flot_axis_timestamp_format(y,axis) {
    return flot_axis_format(y,axis,true);
  }

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

    if ( max<0 ) { return 0; }
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

  function date_from_utc_time(t_) {
    var d = new Date();
    // ugly hack to override a flot bug - formatDate assume the browser timezone
    d.setTime(t_+(60*1000*d.getTimezoneOffset()));
    return d;
  }

  function graph_to_id(graph_) {
    return graph_.replace(/[;:]/g,"_");
  }

  const TIME_UNITS = {s:1, m:60, h:3600, d:3600*24, w:3600*24*7, y:3600*24*365};
  var timeunit_cache = {}
  function timeunit_to_seconds(timeunit_) {
    if ( timeunit_cache[timeunit_] ) {
      return timeunit_cache[timeunit_];
    }
    var m = timeunit_.match(/^(\d+)(\w)$/);
    if ( !m || !m[1] || !m[2] ) { return null; }
    var secs = TIME_UNITS[m[2]];
    var a = parseInt(m[1]);
    timeunit_cache[timeunit_] = a && secs ? secs*a : null;
    return timeunit_cache[timeunit_];
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
      case "NORMAL": return "normal";
    }
    return -1;
  }

  const lookup = {
    0: { title: "Critical", type: "critical", indicator: "danger"},
    1: { title: "Warning", type: "warning", indicator: "warning"},
    2: { title: "Anomaly", type: "anomaly", indicator: "info"},
    3: { title: "Stale", type: "stale", indicator: "default"},
    4: { title: "Normal", type: "normal", indicator: "success"}
  }

  function background_color(selector_) {
    return $(selector_+':eq(0)').css('backgroundColor');
  }

  function foreground_color(selector_) {
    return $(selector_+':eq(0)').css('color');
  }

  function alert_category(alert_) {
    if ( !lookup[0].hex_color ) {
      for (var i in lookup) {
        lookup[i].color = foreground_color('.'+lookup[i].type);
        lookup[i].hex_color = background_color('.'+lookup[i].type);
        lookup[i].idx = parseInt(i);
        lookup[lookup[i].type] = lookup[i]; // allows access by the type name
      }
      // and additinoal helpers
      lookup["crit-high"] = lookup["crit-low"] = lookup.critical;
      lookup["warn-high"] = lookup["warn-low"] = lookup.warning;
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
      var retentions = gs && conf_[gs[0]] && conf_[gs[0]].retentions ? conf_[gs[0]].retentions : null;
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
      // sort based on period
      c.sort(function(a,b) {
        var step_a = a.match(/:(\d+\w+)/);
        var step_b = b.match(/:(\d+\w+)/);
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
  function graph_box_header(container_,options_,more_) {
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
    //$(container_).html($.templates("#graph-box-header-template").render(template_data));
    var $graph_container = $(($(container_).closest(".graph-container"))[0]),
        $box_body = $($graph_container.find(".panel-body")[0]),
        footer = $.templates("#graph-box-footer-template").render(template_data);
    $graph_container.attr("data-graph",template_data[0].graph);
    if ( more_ ) {
      $graph_container.attr("data-graph-more",more_);
    }

    if ( $graph_container.find(".panel-footer") ) {
      $($graph_container.find(".panel-footer")[0]).remove();
    }
    $box_body.parent().append(footer);


    $.each(['graph-yaxis-zoom','graph-delta'],function(_,t) {
      $("."+t).click(function(e) {
        e.stopPropagation();
        var $current = $(e.target),
            cb = $graph_container.data(t+"-switch"),
            paused = $($current.toggleClass("graph-paused")[0]).attr('class'),
            s = paused.indexOf("graph-paused")>-1; // this is a sign the "button" was clicked"
        if ( t=="graph-yaxis-zoom" ) {
          $current.removeClass(s ? "fa-search-plus" : "fa-search-minus");
          $current.addClass(s ? "fa-search-minus" : "fa-search-plus");
        } else {
          // TODO - find an icon to represent delta
        }

        return cb ? cb(e,s) : undefined;
        });
    });
  }

  function setup_menu_alerts() {
    var template_data = [];
    for (var i=0; i<5; ++i) {
      template_data.push(alert_category(i));
    }
    $("#alerts-menu-container").html($.templates("#alerts-menu-template").render(template_data));
  }

  function setup_navbar_right() {
    var template_data = [
      { title: "Search", container: "topnav-search", icon: "search"},
      { title: "Favorites", container: "favorite", icon: "star-o"},
      { title: "Dashboards", container: "dashboards-dropdown-tree", icon: "dashboard"},
      { title: "Recent", container: "recent", icon: "history"},
    ];
    $("#navbar-right-container").html($.templates("#navbar-right-template").render(template_data));
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
      var category = alert_category(category_to_show_);
      for (var i=0; i<5; ++i) {
        var len = alerts[i].length;
        var tr = alert_category(i);
        $("#alert-menu-"+tr.type).text(len);
        if ( category && i!=category.idx ) {
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
          $("#alert-graph-container").html($.templates("#graph-template").render([{klass: "medium-graph"}]));
          $("#alert-graph-container").attr("data-graph",graph);
          setup_graph_header(graph,".graph-header",true,null,"medium-graph");
          load_graph(graph,".graph-body");
          e.stopPropagation();
        });
      }

      if ( category ) {
        show("#alert-box");
        $("#alert-table-container").empty().html($.templates("#alert-table-template").render(template_data));
        var dt = $("#alert-"+category.type).bootstrapTable(
          {
            pagination: true,
            search: true,
            pageSize: 15,
            pageList: [ 15, 30, 60 ],
            formatShowingRows: formatShowingRows,
            formatRecordsPerPage: formatRecordsPerPage,
          }
        );
        set_click_behavior();
        $("#alert-title").text(category.title);
      }
    });
  }

  function teardown_alerts() {
    hide("#alert-box");
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
    new_dashboards.Static = scent_config().static_dashboards;

    scent_config().auto_dashboards(scent_ds,function(autos_) {
      new_dashboards.Auto = autos_;
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

      if ( !new_dashboards.Auto ) {
        return true;
      }
      var tree = [];
      populate_tree(new_dashboards,tree,"");

      var containers = ["#dashboards-dropdown-tree-container","#main-dashboards-container"];

      function force_link_color() {
        // the tree widget forces a style we want to override
        $.each(containers,function(_,c) {
          $(c).find("a[href!='#']").removeAttr("style");
          $(c).find("a[href='#']").removeAttr("href");
        });
      }

      $.each(containers,function(_,c) {
        $(c).treeview({data: tree,
                       enableLinks: true,
        });
      });
      force_link_color(); // TODO - this disappears when the tree is redrawn

      $("#dashboards-dropdown-tree-container").click(function(e) {
        var t = $(e.target);
        if ( t.is("a") && t.attr("href")!='#' ) { return; }
        if ( t.find("a").length==0 || t.find("a[href='#']").length>0 || t.attr("href")=='#' ) {
          e.stopPropagation();
        }
      });

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
      } else {
        sorted_data.push({ graph: "No sub metrics (dialog will automatically close)"});
        $.doTimeout(5000,function() {
          bootbox.hideAll();
        });
      }

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

  function is_graph_paused(graph_container_) {
    return $(graph_container_).hasClass("graph-paused");
  }

  function draw_graph(names_,points_,units_,thresholds_,anomalies_,target_,alert_name_) {
    /*
       if ($(target_).hasClass("tall-graph")) {
       var use_small_fonts = false;
       var x_axis_ticks_count = 10;
       } else {
       var use_small_fonts = true;
       var x_axis_ticks_count = 5;
       }
     */
    var names = names_,
        points = points_,
        $target = $(target_),
        tooltip_prefix = "graph";

    if ( $($target.closest(".graph-body")[0]).hasClass("medium-graph") ) {
      tooltip_prefix = "alert"
    }
    if ( typeof(names_)=="string" ) {
      names = [names_];
      points = [points_];
    }
    if ( names.length!=points.length ) {
      console.log('draw_graph params mismatch');
      notify('Unable to draw the graph(s)',names.join(", "));
      return;
    }
    // the first graph is used for setting up labels
    // the first graph is used for setting up the axes. This may need to be changed.
    var plot_data = [],
        use_timestamp = units_ ? units_[names[0]]=="timestamp" : false,
        formatter = use_timestamp ? flot_axis_timestamp_format : flot_axis_format;

    if ( !use_timestamp ) {
      //console.log("plothover "+use_timestamp+" "+(units_ ? units_[names[0]]=="timestamp" : false));
    }

    var plot_options = {
      xaxis: {
        mode: "time",
        timeformat: choose_timestamp_format(names[0]),
        timezone: "utc",
        minTickSize: choose_tick_size(names[0]),
        font: axis_font,
      },
      yaxis: {
        tickFormatter: formatter,
        ticks: 3,
        font: axis_font,
      },
      legend: {
        show: names.length>1, // we show the legend only if there is a need

        position: "ne",
        _labelFormatter: function(label, series) {
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
		mode: "x",
        color: "#225599"
	  },
      grid: {
		hoverable: true,
		autoHighlight: true,
        color: "white"
	  },
      series: {
        shadowSize: 0,	// Drawing is faster without shadows,
		lines: {
		  show: true,
		},
	  },
    };
    if ( points_[0].length==0 ) {
      // TODO - oddly, if we set this, then inner navigations where data IS available, doesn't
      //        redraw the axis.
      //plot_options.xaxis.ticks = [[0,"No Data"]];
      //plot_options.yaxis.ticks = [0];
    }
    var colors = [lookup[alert_to_css(alert_name_)].color];
    for (var i=1; i<names.length; ++i) {
      colors.push(more_colors[i % more_colors.length]);
    }


    for (var j=0; j<names.length; ++j) {
      var c = colors[j];
      var gs = graph_split(names[j]);
      plot_data.push({
        label: gs[0],
        step: timeunit_to_seconds(gs[1]),
        period: timeunit_to_seconds(gs[2]),
        data: points[j],
        color: c
      });
    }

    if ( thresholds_.length>0 ) {
      var pts = points[0],
          xmin = pts[0][0],
          xmax = pts[pts.length-1][0],
          reveresed = thresholds_.reverse();
      // generate a line for each
      for (var i in reveresed) {
        plot_data.push({
          label: reveresed[i].label,
          color: lookup[reveresed[i].label].color,
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
        $target.removeClass("graph-paused");
        // if it is the first time, we call plot, otherwise, we'll call setData and draw t
        if ( !$target.data("plot") ) {
          $target.data("plot",$.plot(target_,plot_data,plot_options));
        } else {
          var pl = $target.data("plot");
          pl.setData(plot_data);
          pl.setupGrid();
	      pl.draw();
        }
      });
    }

    plot_it();

    $target.on("plotselected", function (event, ranges) {
	  // do the zooming
      var ymax = -1;
      var plot = $target.data("plot");

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
		axis.options.max = ymax*1.02;
      });
	  plot.setupGrid();
	  plot.draw();
	  plot.clearSelection();

      // we add an artificial class to the container so an observer
      // (like the auto refresh code) can check whether the graph is paused.
      $target.addClass("graph-paused");
	});

    $target.off("dblclick"); // clear previous listeners
    $target.on("dblclick",function (e) {
      //console.log("dblclick",is_graph_zoomed(target_));
      if ( is_graph_paused(target_) ) { // if the graph is in paused state, redraw it
        $target.data("plot",null);
        plot_it();
      } else {
        var $tooltip_holder = $($("#"+tooltip_prefix+"-tooltip-table").find(".tooltip-timestamp")[0]),
            v = parseInt($tooltip_holder.attr("data-value")),
            x = parseInt($tooltip_holder.attr("data-timestamp"));
        show_piechart(names[0], date_from_utc_time(x), x/1000, v);
      }
      e.stopPropagation();
    });

    $target.on("plothover",  function (event, pos, item) {
      if ( !$target.data("plot") ) {
        //console.log("no plot found");
        return;
      }
      event.stopPropagation();

      var all_data = $target.data("plot").getData();
      var tooltip_data = [];
      var ts,dv;
      for (var j=0; j<all_data.length; ++j) {
        var dataset = all_data[j].data,
            label = all_data[j].label,
            idx = binarySearch(dataset,pos.x);
        if ( !idx || !dataset[idx] || label.startsWith("crit-") || label.startsWith("warn-") )
          continue;
        ts = dataset[idx][0];
        dv = dataset[idx][1];
        var sec = dataset[idx][1]/all_data[j].step,
            minute = sec*60;

        tooltip_data.push({
          n: label,
          c: all_data[j].color,
          x: dataset[idx][0],
          v: use_timestamp ? formatTimestamp(dataset[idx][1],4) : dataset[idx][1].toLocaleString(),
          sec: sec ? sec.toFixed(2).toLocaleString() : "",
          minute: minute ? minute.toFixed(2).toLocaleString() : "",
        });
      }
      if ( !dv ) { return; }
      var timestamp = time_format(date_from_utc_time(ts));
      if ( $target.closest("#charts-box")[0] ) {
        $($target.closest(".graph-body")[0]).attr("title",tooltip_data[0].v+" @ "+timestamp);
      } else {
        var wrapper = $.templates("#graph-tooltip-wrapper-template").render([{          prefix: tooltip_prefix}]),
          content = $.templates("#graph-tooltip-template").render(tooltip_data),
          container_id = "#"+tooltip_prefix+"-tooltip-container";

        show(container_id);
        $(container_id).html(wrapper);
        var $tooltip_timestamp = $(container_id+" .tooltip-timestamp");
        show($tooltip_timestamp);
        $(container_id+" .tooltip-tbody").html(content);
        $tooltip_timestamp.html(timestamp);
        $tooltip_timestamp.attr("data-value",dv);
        $tooltip_timestamp.attr("data-timestamp",ts);
      }

	});

    $target.on("mouseleave",  function (e) {
      //$("#graph-tooltip").fadeOut(200);
      hide("#"+tooltip_prefix+"-tooltip-container");
      hide("#"+tooltip_prefix+"-tooltip-timestamp");
    });

    var $graph_container = $(($target.closest(".graph-container"))[0]);
    $graph_container.data('graph-yaxis-zoom-switch',function(event, state) {
      var plot = $target.data("plot");
      $.each(plot.getYAxes(), function(_, axis) {
		axis.options.min = state ? null : 0;
        plot_it();
      });
    });

    $graph_container.data('graph-delta-switch',function(event, state) {
      // TODO - add delta calculations
      var all_data = $target.data("plot").getData();
      if ( all_data.length==0 ) {
        return;
      }
      for (var j=0; j<all_data.length; ++j) {
        var data = all_data[j].data,len = data.length;
        var prev = data[0][1];
        if ( state ) {
          for (var i=1; i<len; ++i) {
            var cur = data[i][1];
            data[i] = [data[i][0],Math.max(0,cur-prev),cur];
            prev = cur;
          }
        } else {
          for (var i=1; i<len; ++i) {
            if ( data[i].length==3 ) {
              data[i] = [data[i][0],data[i][2]];
            }
          }
        }
      }

      plot_it();
    });

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

  function load_graph(name_,target_,more_) {
    var names = [name_];

    function callback(raw_data_) {
      if ( !raw_data_ || !raw_data_[name_] || raw_data_[name_].length==0 ) {
        if ( !notified_graphs[name_] ) {
          notify('Unable to load graph','No data for "'+name_+'".');
          notified_graphs[name_] = true;
        }
        //return;
      }
      var units = raw_data_.units,
          data = new Array();
      delete raw_data_.units;

      for (var g in raw_data_) {
        var graph_data = raw_data_[g];
        var d = [];
        for (var rw in graph_data) {
          var current = graph_data[rw];
          d.push([current[2] * 1000,current[0]]);
        }
        d.sort(function(a,b) { return a[0]-b[0]});
        data.push(d);
      };
      //data = fill_in_missing_slots(name_, data)
      //add_bounds(data);

      scent_ds.alerts(function(alerts_) {
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
        draw_graph(names,data,units,thresholds,anomalies,target_,alert_name,more_);
      });

    }

    var graph_url = name_;
    if ( more_ ) {
      graph_url += "/"+more_;
      names = names.concat(more_.split("/"));
    }
    scent_ds.graph(graph_url,callback);
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
      setup_graph_header(name,"#"+id+" .graph-header",true,null,"small-graph");
      load_graph(name,"#"+id+" .graph-body");
    }


    $("#charts-title").text(dashboard_name);


    show("#charts-box");
  }

  function teardown_charts() {
    $("#charts-container").empty();
    hide("#charts-box");
  }

  function setup_checks() {

    function build_status_filter() {
      var records = [
        {criteria:"all", label:"All"},
        {criteria:"normal", label:"Normal"},
        {criteria:"warning", label:"Warning"},
        {criteria:"critical", label:"Critical"},
      ];
      render_template("#checks-table-filter-container","#checks-table-filter-template",
                      {records:records});
      $("#check-status-all").attr("checked","");
      $("#check-status").change( function(e) {
        $("#checks-table").DataTable().draw();
      })
    }

    function callback(checks_) {
      var records = [];
      var ignore_pat = /;1s:1s$/;

      $.each(checks_,function(k,v) {
        if ( ignore_pat.test(k) ) {
          return;
        }
        var status; // TODO - translate to normal/warning/critical/flapping
        var ts;
        records.push({check: k, status: status, time: ts});
      });

      render_template("#checks-table-container","#checks-table-template",{records:records});
      var dt = $("#checks-table").DataTable({
        bRetrieve: true,
        iDisplayLength: 40,
        aLengthMenu: [ 40, 80, 120 ],
        destroy: true,
        order: [[ 0, "asc" ]]
      });

      $.fn.dataTable.ext.search.push(
        function( settings, data, dataIndex ) {
          // TODO - get the radio group state and filter accordingly
          var criteria = $("#check-status").val();
          var min = parseInt( $('#min').val(), 10 );
          var max = parseInt( $('#max').val(), 10 );
          var status = data[1];

        return criteria==status;
        });
      build_status_filter();
      // TODO - setup event on radio group change
      //$("#checks-criteria").
    }


    scent_ds.latest("checker",callback);
  }

  function teardown_checks() {
    $("#checks-table-container").empty();
    hide("#checks-box");
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

  function setup_graph_header(name_,graph_header_container_,inner_navigation_,
                              remove_callback_,klass_,more_) {

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
                            full: !!inner_navigation_, remove: !!remove_callback_},more_);
          if ( remove_callback_ ) {
            $(".graph-remove").off("click").click(remove_callback_);
          }

          var $graph_container = $(($(graph_header_container_).closest(".graph-container"))[0]);
          var container_id = "#"+$graph_container.attr("id");

          $(container_id+" .inner-navigation").click(function(e) {
            e.stopPropagation();
            var href = $(e.target).attr("data-graph"); // this is the graph to be shown
            var container = ($(e.target).closest(".graph-container"))[0];
            var graph = $(container).attr("data-graph"); // this is the existing graph
            var graph_view = $(container).find(".graph-view");
            console.log('inner navigation %s', graph);
            setup_graph_header(href,container_id+" .graph-header",true,
                               remove_callback_,klass_,more_);
            load_graph(href,container_id+" .graph-body");
            graph_view.parent().attr("href","#/graph/"+href);
          });


          $(container_id+" .graph-favorite").click(function(e) {
            e.stopPropagation();
            var $target = $(e.target),
                container = $target.closest(".graph-container"),
                graph = $(container[0]).attr("data-graph");
            // we should re-read the persistent data
            load_persistent(function(persistent_) {
              var favorites = persistent_.favorites;
              var idx = favorites.indexOf(graph);
              console.log('favorite %s %s', graph, favorites);
              if ( idx==-1 ) { // we need to add to favorites
                favorites.push(graph);
                $target.attr("class","graph-favorite fa fa-star");
              } else {
                favorites.splice(idx,1);
                $target.attr("class","graph-favorite fa fa-star-o");
              }
              scent_ds.save(user,"persistent",persistent_,function() {
                setup_menus();
              });
            });
          });

          $(container_id+" .graph-set-alerts").click(function(e) {
            e.stopPropagation();
            function callback(alerts_) {
              var $target = $(e.target),
                  container = $target.closest(".graph-container"),
                  graph = $(container[0]).attr("data-graph"),
                  graph_alerts = alerts_[graph],
                  suggested = false;

              if ( !graph_alerts ) {
                var all_data = $(container).find(".graph-body").data("plot").getData(),min,max;
                suggested = true;
                graph_alerts = [];
                // TODO - go over the data and suggest values. Place them in graph_alerts
                if ( all_data.length>0 ) {
                  var first = all_data[0].data,len = first.length
                  for (var i=0; i<len; ++i) {
                    var v = first[i][1];
                    min = min ? Math.min(min,v) : v;
                    max = max ? Math.max(max,v) : v;
                  }
                  if ( min ) {
                    graph_alerts[0] = (min*0.95).toFixed();
                    graph_alerts[1] = (min*1.1).toFixed();
                    graph_alerts[2] = (max*0.9).toFixed();
                    graph_alerts[3] = (max*1.05).toFixed();
                  }
                }
                var step = graph_step_in_seconds(name_)
                graph_alerts[4] = step;
                graph_alerts[5] = step*3;
              }
              var fields = $.templates("#alert-modal-template").render([
                { label:"Critical High", id: "crit-high", color: lookup.critical.color,
                  value: graph_alerts[3]},
                { label:"Warning High", id: "warn-high", color: lookup.warning.color,
                  value: graph_alerts[2]},
                { label:"Warning Low", id: "warn-low", color: lookup.warning.color,
                  value: graph_alerts[1],},
                { label:"Critical Low", id: "crit-low", color: lookup.critical.color,
                  value: graph_alerts[0],},
                { label:"Period", id: "period",
                  value: formatTimestamp(graph_alerts[4])},
                { label:"Stale", id: "stale", color: lookup.stale.color,
                  value: formatTimestamp(graph_alerts[5])}
              ]);
              $("#alert-modal-form-container").html(fields);
              var html = $("#alert-modal").html();
              function empty_container() {
                $("#alert-modal-form-container").empty();
              }

              bootbox.dialog({
                title: "Create/Update Alert"+(suggested ? " <small>(suggested values)</small>" : ""),
                message: html,
                onEscape: empty_container,
                buttons: {
                  cancel: {
                    label: "Cancel",
                    callback: empty_container,
                  },
                  success: {
                    label: "Save",
                    callback: function() {
                      empty_container();
                      var values = [$("#crit-low").val(),$("#warn-low").val(),
                                    $("#warn-high").val(),$("#crit-high").val(),
                                    timeunit_to_seconds($("#period").val()),
                                    timeunit_to_seconds($("#stale").val())];
                      // only stale is optional
                      if ( values[0] && values[1] && values[2] && values[3] && values[4] ) {
                        scent_ds.set_alert(graph,values,refresh_loaded_graphs_now);
                      }
                    }
                  }
                }
              });
            }

            scent_ds.alerts(callback);
          });

        });

      });
    });
  }

  function keys_table_helper(key_,target_,plus_) {
    var metric = graph_split(key_) || [key_];
    scent_ds.key(key_ || "",function(keys_) {
      if ( keys_.length==0 ) {
        var parent_key = key_.replace(/\.[^\.;]+(;\d\w+:\d\w+)?$/,"");
        if ( parent_key==key_ ) {
          parent_key = key_.replace(/(;\d\w+:\d\w+)?$/,"");
          }
        if ( parent_key!=key_ ) { return keys_table_helper(parent_key,target_,plus_); }
      }
      var first_key = keys_.length==1 ? keys_[0] : null;
      if ( first_key && first_key!=key_ && !first_key.includes(";") ) {
        return keys_table_helper(first_key,target_,plus_);
      }
      populate_keys_table(metric[0],keys_,target_,plus_);
    },true);
  }

  function setup_graph(name_,more_) {
    render_template("#graph-box-container","#graph-template",[{klass: "tall-graph"}]);
    setup_graph_header(name_,"#graph-box .graph-header",true,null,"tall-graph",more_);
    load_graph(name_,"#graph-box .graph-body",more_);
    show("#graph-box");

    keys_table_helper(name_,"#graph-box-keys-container",true);
    push_graph_to_recent(name_);
  }

  function teardown_graph() {
    hide("#graph-box");
    $("#graph-box-container").empty();
  }

  function populate_keys_table(parent_key_,keys_,target_,plus_) {
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
    var hash = window.location.hash;
    var first_graph_rp = hash.match(/#graph\/[\w\[\]\.\-]+(;\d\w+:\d\w+)?/);
    for (var i in unified) {
      var in_url = hash.indexOf(i+";"); // we add the ";" to make sure this isn't a prefix match
      var metric_parts = i.split(".");
      var record = {key: i, short_key: metric_parts[metric_parts.length-1], links: unified[i]}
      if ( plus_ && unified[i].length>1 ) {
        if ( in_url==-1) {
          record.plus = [hash,"/",i,first_graph_rp[1]].join("");
        } else if ( in_url>7 ) { // 7 is "#graph/".length which is true only for the primary
          record.minus = hash.replace(["/",i,first_graph_rp[1]].join(""),"");
        }
      }
      records.push(record);
    }


    function set_header(key) {
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
      } else {
        $(target_+"-header").empty();
      }
    }
    function set_click_behavior() {
      // thanks http://stackoverflow.com/a/19684440

      // TODO - when clicking a link in the popover, the popover should be hidden
      $(".keys-table-key").popover().on("mouseenter",function () {
        var _this = this;
        $(this).popover("show");
        $(".popover").on("mouseleave", function () {
          $(_this).popover('hide');
        });

        $(".keys-table-popover-title").click(function(e) {
          var key = $(e.target).attr("data-target");

          set_header(key);
          keys_table_helper(key,target_,plus_);

          e.stopPropagation();
        });


      }).on("mouseleave", function () {
        var _this = this;
        setTimeout(function () {
          if (!$(".popover:hover").length) {
            $(_this).popover("hide");
          }
        }, 5);
      });

    }

    $(target_).empty().html($.templates("#keys-table-template").render({records: records}));
    set_header(parent_key_);
    var dt = $("#keys-table").bootstrapTable(
      {
        pagination: true,
        search: true,
        smartDisplay: true,
        pageSize: 10,
        pageList: [ 10, 20, 40 ],
        formatShowingRows: formatShowingRows,
        formatRecordsPerPage: formatRecordsPerPage,
        onPageChange: set_click_behavior,
      }
    );

    set_click_behavior();

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
      populate_keys_table(key_,keys_,"#main-keys-container")
    },true);

    show("#main-box");
  }

  function teardown_main() {
    hide("#main-box");
  }

  function set_title(title_) {
    $("title").text("Scent of a Mule | "+title_);
    //$("#page-title").text(title_);
    //$("#qunit > a").text(title_);
  }

  function refresh_loaded_graphs_now() {
    $(".graph-body").each(function(idx_,obj_) {
      var container = ($(obj_).closest(".graph-container"))[0];
      var container_box = ($(container).closest(".box"))[0];
      if ( $(container_box).css("display")=="none" ) {
        return;
      }
      var graph_container_id = "#"+$(container).attr('id')+" .graph-body";
      if ( is_graph_paused(graph_container_id) ) {
        return;
      }
      var graph = $(container).attr("data-graph");
      var more = $(container).attr("data-graph-more");

      if ( graph_split(graph) ) {
        load_graph(graph,graph_container_id,more);
        //console.log('refresh_loaded_graphs: %s',graph);
      }
    });
    return true;
  }
  function refresh_loaded_graphs() {
    $.doTimeout(scent_config().graphs_refersh_rate*1000,refresh_loaded_graphs_now);

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
      setup_navbar_right();
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
      teardown_checks();
    });

    router.get('alert/:category', function(req) {
      set_title("Alert");
      var category = req.params.category;
      globals();
      teardown_main();
      teardown_charts();
      teardown_graph();
      teardown_alerts(); // we need to clear the displayed alert table/graph when navigating between alerts
      teardown_checks();
      update_alerts(category);
      refresh_loaded_graphs();
    });

    router.get('checks', function(req) {
      set_title("Checks");
      var category = req.params.category;
      globals();
      teardown_main();
      teardown_charts();
      teardown_graph();
      teardown_alerts();
      setup_checks();
      refresh_loaded_graphs();
    });

    function route_graph(id,more) {
      set_title("Graph");
      globals();
      teardown_main();
      teardown_alerts();
      teardown_checks();
      teardown_charts();
      setup_graph(id,more);
      refresh_loaded_graphs();
    }
    // couldn't manage to get grapnel handle these two patterns in the same route...
    router.get('graph/:id', function(req) {
      route_graph(req.params.id);
    });

    router.get('graph/:id/*', function(req) {
      var more = [];
      for (var i=1; req.params[i]; ++i) {
        more.push(req.params[i]);
      }
      route_graph(req.params.id,more.join("/"));
    });

    router.get('dashboard/:id', function(req) {
      set_title("Dashboard");
      globals();
      var id = req.params.id;
      teardown_main();
      teardown_alerts();
      teardown_checks();
      teardown_graph();
      setup_charts(id);
      refresh_loaded_graphs();
    });

    router.on('navigate', function(event){
      //console.log('URL changed to %s', this.fragment.get());
    });
  }

  setup_footer();

  // call init functions
  setup_pnotify();

  setup_router();
}

$(app);
