function delayed(func_) {
  $.doTimeout(2,func_);
}


function string_set_keys(set_) {
  return $.map(set_ || {},function(key_,idx_) { return idx_; });
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

const synthetic_key = /^(.+?)(;1s:1s)$/;

function key_impl(initial_,key_,callback_,raw_,remove_synthetic_) {
  var k = $.map(initial_,function(element,index) {return index});
  var rv = {};
  var add_rp = /;$/.test(key_) || raw_;

  var ks = string_set_keys(rv);
  if ( remove_synthetic_ ) {
    k = k.filter(function(e) { return !synthetic_key.test(e); });
  } else {
    k = $.map(k,function(e) {
      var match = synthetic_key.exec(e);
      return match ? match[1] : e;
    });
  }
  callback_(k.filter(function(e) { return raw_ ? true : e!=key_;}).sort());
}

function search_impl(initial_,key_,callback_) {
  callback_($.map(initial_,function(element,index) {return index}).sort());
}

function deep_key(table_,key_) {
  var parts = key_.split(".");
  var current = table_;
  for (var i=0; i<parts.length && current; ++i) {
    current = current[parts[i]];
  }
  return current;
}


function render_template(target_,template_,data_) {
  $(target_).empty().html($.templates(template_).render(data_));
}

function hide(selector_) {
  $(selector_).toggleClass("hidden",true);
}

function show(selector_) {
  $(selector_).toggleClass("hidden",false);
}
