
function mule_ds() {
  var conf = scent_config();
  var ns = $.initNamespaceStorage(conf.namespace);
  const user = conf.user;
  const mule_server = conf.server;
  var cache = new Cache(conf.cache_size);


  function mule_get(resource_,callback_,cache_period_) {
    var cached = cache.getItem(resource_);
    if ( cached ) {
      //console.log("cache hit: %s",resource_);
      delayed(callback_(cached));
      return;
    }

    $.ajax({
      url: mule_server+resource_,
      async: true,
      dataType: 'json',
      timeout: 20*1000,
      success: function (response_) {
        if ( cache_period_ ) {
          cache.setItem(resource_,response_.data,{expirationAbsolute: null,
                                                  expirationSliding: cache_period_,
                                                  priority: Cache.Priority.HIGH,
                                                  callback: function(k, v) {
                                                    //console.log("cache remove: %s",k);
                                                  }
                                                 });
        }
        callback_(response_.data);
      },
      error: function(xhr_,internal_error_,http_status_) {
        console.log("%s <%s,%s>",resource_,internal_error_,http_status_);
      }
    });
  }

  function config(path_,callback_) {
    var url = "/config"+ (path_ ? "/"+path_ : "");
    mule_get(url,callback_,120);
  }

  function graph(graph_,callback_) {
    mule_get("/graph/"+graph_+"?filter=now",function(data_) {
      callback_(data_);
    },30);
  }

  function piechart(graph_,time_,callback_) {
    mule_get("/graph/"+graph_+"?count=100&level=1&timestamp="+time_,function(data_) {
      callback_(data_);
    },30);
  }

  function key(key_,raw_,remove_synthetic_,callback_) {
    if ( $.isFunction(raw_) ) {
      callback_ = raw_;
    }
    if ( $.isFunction(remove_synthetic_) ) {
      callback_ = remove_synthetic_;
    }
    if (key_[key_.length-1]=='.' ) {
      key_ = key_.slice(0,key_.length-1);
    }
    mule_get("/key/"+key_+"?level=1",
             function(keys_) {
               return key_impl(keys_,key_,callback_,raw_,remove_synthetic_);
             },300);
  }

  function search(key_,callback_) {
    if ( key_.length<3 ) {
      return;
    }
    mule_get("/key/"+key_+"?level=1&search=true",
             function(keys_) {
               return search_impl(keys_,key_,callback_);
             },300);
  }

  function latest(graph_,callback_) {
    mule_get("/latest/"+graph_+"?level=3",function(data_) {
      callback_(data_);
    },30);
  }

  function alerts(callback_) {
    mule_get("/alert",callback_,60);
  }

  function set_alert(graph_,alert_values_,callback_) {
    var path = ["/alert/",graph_].join(""),
        data = ["critical_low=",alert_values_[0],"&warning_low=",alert_values_[1],
                "&warning_high=",alert_values_[2],"&critical_high=",alert_values_[3],
                "&period=",alert_values_[4],"&stale=",alert_values_[5]].join("");
    $.ajax({
      method: "PUT",
      url: mule_server+path,
      data: data,
      async: true,
      timeout: 20*1000,
      success: function (response_) {
        cache.clear();
        callback_(response_.data);
      },
      error: function(xhr_,internal_error_,http_status_) {
        console.log("%s <%s,%s>",path,internal_error_,http_status_);
      }
    });
  }
  // if key == "persistent" the data is taken from the server, otherwise session storage
  // is used
  function load(user_,key_,callback_) {
    delayed(function() {
      try {
        if (key_=="persistent" ) {
          callback_(ns.localStorage.get(user_+".persistent"));
        } else {
          callback_(ns.sessionStorage.get(user_+"."+key_));
        }
      } catch(e){
        callback_(null);
      }
    });
  }

  function save(user_,key_,data_,callback_) {
    delayed(function() {
      if (key_=="persistent" ) {
        ns.localStorage.set(user_+".persistent",data_);
        if ( callback_ ) {
          callback_();
        }
        return;
      }
      ns.sessionStorage.set(user_+"."+key_,data_);
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
    search : search,
    alerts : alerts,
    set_alert : set_alert,
    latest : latest,
    load: load,
    save: save,
  }

}
if ( /\/test\//.test(location.href) ) {
  $.getScript("./tests.js");
}
scent_ds = /\/test\//.test(location.href) ? mule_mockup() : mule_ds();
