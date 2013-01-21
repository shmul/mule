local pp = require "purepack"

function sequence_storage(db_,name_,numslots_)
  local _data = nil

  local function get_cell(idx_,offset_)
    -- idx_ is zero based
    local i = 1+(idx_*18)+offset_*6
    return pp.from_binary(string.sub(_data,i,i+5))
  end

  local function set_cell(idx_,offset_,value_)
    -- idx_ is zero based
    local i = 1+(idx_*18)+offset_*6
    _data = string.sub(_data,1,i-1)..pp.to_binary(value_)..string.sub(_data,i+6)
  end

  local function save()
    db_.put(name_,_data)
  end

  local function reset()
    _data = string.rep(pp.to_binary(0),3*numslots_+1)
    return _data
  end


  _data = db_.get(name_) or reset()

  return {
    get_cell = get_cell,
    set_cell = set_cell,
    save = save,
    reset = reset
         }
end
