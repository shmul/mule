local pp = require "purepack"

function sequence_storage(db_,name_,numslots_)
  local _data = nil

  local function get_cell(idx_,offset_)
    -- idx_ is zero based
    local fromb,sub = pp.from_binary,string.sub
    if offset_ then
      local i = 1+(idx_*18)+offset_*6
      return fromb(sub(_data,i,i+5))
    end
    local i = 1+(idx_*18)
    return fromb(sub(_data,i,i+5)),fromb(sub(_data,i+6,i+11)),fromb(sub(_data,i+12,i+17))
  end


  local function set_cell(idx_,offset_,a,b,c)
    -- idx_ is zero based
    local tob,sub = pp.to_binary,string.sub
    if offset_ then
      local i = 1+(idx_*18)+offset_*6
      _data = sub(_data,1,i-1)..tob(a)..sub(_data,i+6)
      return
    end
    local i = 1+(idx_*18)
    _data = sub(_data,1,i-1)..tob(a)..tob(b)..tob(c)..sub(_data,i+18)
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
