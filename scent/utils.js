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

function key_impl(initial_,key_,callback_,raw_) {
  var k = $.map(initial_,function(element,index) {return index});
  var rv = {};
  var add_rp = /;$/.test(key_) || raw_;
  var synthetic_key = /^(.+?)(;1s:1s)$/;

  function push_key(e,dont_trim) {
    if ( add_rp || dont_trim) {
      rv[e] = true;
    } else
      rv[e.replace(/;.+$/,"")] = true;
  }

  if ( key_=="" ) { // no dots -> bring top level only
    $.each(k,function(idx,e) {
      if ( /^[\w-]+;/.test(e) )
        push_key(e);
    });
  } else {
    var re = new RegExp("^" + key_+"[\\w;:-]*"); //  var re = new RegExp("^" + key_+"[\\w:;-]+");
    var key_sc = key_+";";
    $.each(k,function(idx,e) {
      if ( re.test(e) )
        push_key(e,e.startsWith(key_sc));
    });
  }

  var fks = $.map(string_set_keys(rv),function(e) {
    var match = synthetic_key.exec(e);
    return match ? match[1] : e;
  }).filter(function(e) { return e!=key_;});
  callback_(fks.sort());
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
