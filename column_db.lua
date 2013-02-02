module("column_db",package.seeall)
require "helpers"

local _,p = pcall(require,"purepack")
local _,sl = pcall(require,"skiplist")

--[[
Sequences are stored column by column, i.e. all the Nth slots of each sequences are stored
sequentially. Every sequence is assigned a global id which places it in a "bucket" file with M many other sequences.

definitions:
  - cell - a single numeric value, 4, 6 or 8 bytes long (depending on purepack)
  - slot - trio of cells, timestamp, value, sum
  - offset - the cell index within the slot
  - id - a global running counter of the name
  - idx - the column to updated
  - sid - sequence id with in the store

--]]

function cell_store(file_,num_sequences_,slots_per_sequence_,slot_size_)
  local file = nil
  local dirty = false

  local function reset()
    local file_size = num_sequences_*slots_per_sequence_*slot_size_
    logi("creating file",file_,file_size)

    file = io.open(file_,"r+b") or io.open(file_,"w+b")
    file:seek("set",file_size-1)
    file:write("%z")
    file:close()

--[[
    local block_size = 16384
    local cmd = string.format("dd if=/dev/zero of=%s bs=%d count=%d &> /dev/null",
                              file_,block_size,math.ceil(file_size/block_size))
    os.execute(cmd)
    --]]
  end

  local function open()
    file = io.open(file_,"r+b") or io.open(file_,"w+b")
    if not file then
      loge("unable to open column store",file_)
      return nil
    end
    logd("opened column store",file_)
  end

  local function close()
    if file then
      logd("closed column store",file_)
      file:close()
    end
  end


  local function flush()
    if file and dirty then
      logd("flush",file_)
      file:flush()
      dirty = false
    end
  end

  -- zero based
  local function seek(sid_,idx_)
    if not file then
      logw("no file")
      return nil
    end
    local cell_pos = slot_size_*(sid_+slots_per_sequence_*idx_)
    return file:seek("set",cell_pos)
  end

  local function read_cell(sid_,idx_)
    if seek(sid_,idx_) then
      return file:read(slot_size_)
    end
  end

  local function write_cell(sid_,idx_,slot_)
    if seek(sid_,idx_) then
      dirty = true
      return file:write(string.sub(slot_,1,slot_size_))
    end
  end

  if not file_exists(file_) then
    reset()
  end
  open()


  return {
    close = close,
    flush = flush,
    read = read_cell,
    write = write_cell,
    size = function() return slots_per_sequence_ end
         }
end


SEQUENCES_PER_FILE = 2000
SAVE_PERIOD = 60

function column_db(base_dir_)
  local index = sl:new()
  local meta_file = base_dir_.."/db.meta"
  local cell_store_cache = {}
  local last_save = nil

  local function extract_from_name(name_)
    local node = index[name_]

    if not node then
      local metric,step,period = split_name(name_)
      node = index:insert(name_)
      node.metric = metric
      node.step = step
      node.period = period
      node.value = index.size-1
      node.latest = 0
    end

    return node.metric,node.step,node.period,node.value
  end

  local function latest(name_,idx_)
    local node = index[name_]
    if not node then
      loge("no such node",name_)
      return
    end
    if idx_ then
      node.latest = idx_
    end
    return node.latest
  end

  local function read_meta_file()
    with_file(meta_file,
              function(f_)
                index:unpack(f_:read("*a"))
              end,"r+b")
  end

  local function save_meta_file()
    with_file(meta_file,
              function(f_)
                f_:write(index:pack())
                f_:flush()
              end,"w+b")
  end


  local function save_all(close_)
    logi("save_all",close_)
    for k,cdb in pairs(cell_store_cache) do
      cdb:flush()
      if close_ then
        cdb:close()
      end
    end
    if close_ then
      cell_store_cache = {}
    end
    save_meta_file()
  end

  local function find_file(name_)
    local metric,step,period,id = extract_from_name(name_)
    -- we normalize the step,period variables to canonical time units
    -- we add 1 to the period/step to accomodate the latest value at the last slot
    local file_name = string.format("%s/%s.%s.%d.cdb",base_dir_,
                                    secs_to_time_unit(step),
                                    secs_to_time_unit(period),
                                    id / SEQUENCES_PER_FILE)
    local cdb = cell_store_cache[file_name]

    -- save all the files every SAVE_PERIOD
    if not last_save or os.time()>last_save+SAVE_PERIOD then
      last_save = os.time()
      save_all()
    end

    if not cdb then
      cdb = cell_store(file_name,SEQUENCES_PER_FILE,period/step,p.PNS*3) -- 3 items per slot
      cell_store_cache[file_name] = cdb
    end
    return cdb,id % SEQUENCES_PER_FILE
  end


  local function with_cell_store(name_,func_)
    local cdb,sid = find_file(name_)
    return func_(cdb,sid)
  end

  local function put(key_,value_)
    local node = index[key_]
    local is_metadata = string.find(key_,"metadata=",1,true)

    -- value is updated only for metadata nodes
    if not node then
      node = index:insert(key_)
      -- to all non metadata keys we assign a global id. This id is used for storing
      -- the actual sequences
      if not is_metadata then
        index.head.id = (index.head.id or -1) + 1
        node.value = index.head.id
      end
    end
    if is_metadata then
      node.value = value_
    end
  end

  local function get(key_)
    local node = index[key_]
    if node and string.find(key_,"metadata=",1,true) then
      return node.value
    end
  end

  local function out(key_)
    return index:delete(key_)
  end

  local function matching_keys(prefix_)
    local find = string.find
    local node = index:find(prefix_)
    -- first node may not match the prefix as it the largest element <= prefix_
    if node.key<prefix_ or node.key=="HEAD" then
      node = index:next(node)
    end
    return coroutine.wrap(
      function()
        while node and node.key and find(node.key,prefix_,1,true) do
          if not find(node.key,"metadata=",1,true) then
            coroutine.yield(node.key)
          end
          node = index:next(node)
        end
      end)
  end

  local function internal_get_slot(name_,idx_,offset_)
    return with_cell_store(name_,
                        function(cdb_,sid_)
                          -- trying to access one past the cdb size is interpreted as
                          -- getting the latest index
                          if cdb_.size()==idx_ then
                            return latest(name_)
                          end

                          local slot = cdb_.read(sid_,idx_)
                          return get_slot(slot,0,offset_)
                        end
                       )
  end

  local function internal_set_slot(name_,idx_,offset_,a,b,c)
    return with_cell_store(name_,
                        function(cdb_,sid_)
                          -- trying to access one past the cdb size is interpreted as
                          -- setting the latest index
                          if cdb_.size()==idx_ then
                            return latest(name_,a)
                          end

                          local t,u,v,w,x = set_slot(cdb_.read(sid_,idx_),0,offset_,a,b,c)
                          if offset_ then
                            cdb_.write(sid_,idx_,t..u..v)
                          else
                            cdb_.write(sid_,idx_,u..v..w)
                          end
                        end
                       )
  end

  if not file_exists(meta_file) then
    os.execute("mkdir -p "..base_dir_.." &> /dev/null")
  end

  read_meta_file()
  local self = {
    save = save_meta_file,
    put = put,
    get = get,
    out = out,
    close = function()
      save_all()
    end,
    set_slot = internal_set_slot,
    get_slot = internal_get_slot,
    matching_keys = matching_keys,
    sort_updated_names = function(names_)
      -- TODO - is it worth it?
      table.sort(names_,
                 function(a_,b_)
                   local _,_,_,a = extract_from_name(a_)
                   local _,_,_,b = extract_from_name(b_)
                   return a<b
                 end)
      return names_
    end
  }


  self.sequence_storage = function(name_,numslots_)
    return {
      get_slot = function(idx_,offset_)
        return self.get_slot(name_,idx_,offset_)
      end,
      set_slot = function(idx_,offset_,a,b,c)
        return self.set_slot(name_,idx_,offset_,a,b,c)
      end,
      save = function() -- nop
      end,
      reset = function() print("reset",name_) end,
           }
  end

  return self
end