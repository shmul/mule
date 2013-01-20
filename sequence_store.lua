local pp = require "purepack"

function sequence_storage(db_)
  local _data = nil

  local function get_raw(idx_,offset_)
    -- idx_ is zero based
    local i = 1+(idx_*18)+offset_*6
    return pp.from_binary(string.sub(_data,i,i+5))
  end

  local function set_raw(idx_,offset_,value_)
    -- idx_ is zero based
    local i = 1+(idx_*18)+offset_*6
    _data = string.sub(_data,1,i-1)..pp.to_binary(value_)..string.sub(_data,i+6)
  end

  local function save(name_)
    db_.put(name_,_data)
  end

  local function init(numslots_)
    _data = string.rep(pp.to_binary(0),3*numslots_+1)
    return _data
  end

  local function get_or_init(name_,numslots_)
    _data = db_.get(name_) or init(numslots_)
    return _data
  end

  return {
    get_raw = get_raw,
    set_raw = set_raw,
    save = save,
    init = init,
    get_or_init = get_or_init,
         }
end
