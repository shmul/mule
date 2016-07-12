--module("column_db",package.seeall)
require "helpers"

--local lr = require("luarocks.require")
local p = require("purepack")
local tr = require("trie")
local unpack_compatibility = _G.unpack or table.unpack

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


local PACK_FACTOR = 100
local function cell_store(file_,num_sequences_,slots_per_sequence_,slot_size_)
  local file = nil
  local dirty = false

  local function reset()
    local file_size = num_sequences_*PACK_FACTOR*(math.ceil(slots_per_sequence_/PACK_FACTOR))*slot_size_
    logi("creating file",file_,file_size)

    file = io.open(file_,"r+b") or io.open(file_,"w+b")
    if not file then
      return nil
    end
    file:seek("set",file_size-1)
    file:write("\0")
    file:close()
    file = nil

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
      file = nil
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
    local p = math.floor(idx_/PACK_FACTOR)
    local q = idx_%PACK_FACTOR
    local cell_pos = slot_size_*((p*num_sequences_*PACK_FACTOR)+sid_*PACK_FACTOR+q)
    return file:seek("set",cell_pos)
  end

  local function read_cell(sid_,idx_)
    if seek(sid_,idx_) then
      return file:read(slot_size_)
    end
    loge("read_cell failure")
  end

  local function write_cell(sid_,idx_,slot_)
    if seek(sid_,idx_) then
      dirty = true
      return file:write(string.sub(slot_,1,slot_size_))
    end
    loge("write_cell failure")
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
SAVE_PERIOD = 60*10

local function column_db(base_dir_)
  local index = tr:new()
  local dirty = false
  local meta_file = base_dir_.."/db.meta"
  local cell_store_per_file_cache = {}
  local cell_store_per_name_cache = {}
  local last_save = nil
  local seq_cache = {}
  local seq_cache_size = 0
  local _increment = nil
  logi("column_db")

  local function create_node(name_)
    local node = index:find(name_)

    if not node then
      local metric,step,period = split_name(name_)
      node = index:insert(name_)
      dirty = true
      node.metric = metric
      node.step = step
      node.period = period
      node.value = index:size()-1 + index:find("metadata=column_db_deleted").count
      node.latest = 0
    end

    return node
  end

  local function extract_from_name(name_)
    local node = create_node(name_)
    return node.metric,node.step,node.period,node.value
  end

  local function latest(name_,idx_)
    local node = index:find(name_)
    if not node then
      loge("no such node",name_)
      return
    end
    if not node.latest then
      logw("no latest value")
      node.latest = 0
    end
    if idx_ then
      node.latest = idx_
    end
    return node.latest
  end

  local function read_meta_file()
    with_file(meta_file,
              function(f_)
                index = tr.unpack(f_:read("*a"))
              end,"r+b")
  end

  local function save_meta_file()
    local function helper()
      local tmp_meta = string.format("%s.%s.tmp",meta_file,os.date("%y%m%d-%H%M%S"))
      local save_successful = with_file(tmp_meta,
                                        function(f_)
                                          f_:write(index:pack())
                                          f_:flush()
                                          return true
                                        end,"w+b")
      if not save_successful then
        loge("unable to same meta file")
        return false
      end
      os.rename(tmp_meta,meta_file)
      logi("save_meta_file. size",index:size())
      return true

    end

    local function lock_and_save()
      posix_lock(meta_file..".lock",function()
                   logi("save_meta_file",dirty)
                   if not dirty then
                     return
                   end
                   helper()
                   dirty = false
      end)
    end


    fork_and_exit(lock_and_save)
  end


  local function save_all(close_)
    logi("save_all",close_)
    for _,cdb in pairs(cell_store_per_file_cache) do
      cdb:flush()
      if close_ then
        cdb:close()
      end
    end
    if close_ then
      cell_store_per_file_cache = {}
      cell_store_per_name_cache = {}
    end
    save_meta_file()
  end

  local function find_file(name_)
    local cached = cell_store_per_name_cache[name_]
    if cached then
      return cached.cdb,cached.id % SEQUENCES_PER_FILE
    end

    local metric,step,period,id = extract_from_name(name_)

    -- we normalize the step,period variables to canonical time units
    -- we add 1 to the period/step to accomodate the latest value at the last slot
    local file_name = string.format("%s/%s.%s.%d.cdb",base_dir_,
                                    secs_to_time_unit(step),
                                    secs_to_time_unit(period),
                                    math.floor(id / SEQUENCES_PER_FILE))
    local cdb = cell_store_per_file_cache[file_name]
    if not cdb then
      cdb = cell_store(file_name,SEQUENCES_PER_FILE,period/step,p.PNS*3) -- 3 items per slot
      cell_store_per_file_cache[file_name] = cdb
    end
    cell_store_per_name_cache[name_] = { cdb = cdb, id = id }
    return cdb,id % SEQUENCES_PER_FILE
  end


  local function with_cell_store(name_,func_)
    local cdb,sid = find_file(name_)
    return func_(cdb,sid)
  end

  local function put(key_,value_)
    local node = index:find(key_)
    local is_metadata = special_key(key_)
    dirty = true
    -- value is updated only for metadata nodes
    if not node then
      node = index:insert(key_)
    end
    if is_metadata then
      node.value = value_
    end
  end

  local function get(key_)
    local node = index:find(key_)
    if node and special_key(key_) then
      return node.value
    end
  end

  local function find_keys(prefix_,substring_)
    local gsub = string.gsub
    local find = string.find
    local function put_semicolumn(rp)
      return ";"..rp
    end
    return coroutine.wrap(
      function()
        for k,n in index:traverse(prefix_,true,false) do
          if find(k,substring_,1,true) then
            coroutine.yield(gsub(k,"%.(%d+%w:%d+%w)$",put_semicolumn))
          end
        end
    end)
  end

  local function has_sub_keys(prefix_)
    local gsub = string.gsub
    local find = string.find
    local function put_semicolumn(rp)
      return ";"..rp
    end
    for k,n in index:traverse(prefix_,true,false) do
      if k~=prefix_ then
        return true
      end
    end
  end

  local function matching_keys(prefix_,level_)
    local gsub = string.gsub
    local find = string.find
    local function put_semicolumn(rp)
      return ";"..rp
    end
    if #prefix_==0 then
      level_ = 2
    else
      level_ = level_ and level_+1
    end
    return coroutine.wrap(
      function()
        for k,n in index:traverse(prefix_,true,false) do
          if bounded_by_level(k,prefix_,level_) then
            coroutine.yield(gsub(k,"%.(%d+%w:%d+%w)$",put_semicolumn))
          end
        end
    end)
  end

  local function internal_get_slot(name_,idx_,offset_)
    return with_cell_store(name_,
                           function(cdb_,sid_)
                             -- trying to access one past the cdb size is interpreted as
                             -- getting the latest index
                             if idx_==cdb_.size() then
                               return latest(name_)
                             end
                             local cached = seq_cache[name_]
                             if cached then
                               if not offset_ then
                                 return unpack_compatibility(cached[idx_+1])
                               end
                               return cached[idx_+1][offset_+1]
                             end
                             local slot = cdb_.read(sid_,idx_)
                             return get_slot(slot,0,offset_)
                           end
    )
  end

  local function internal_set_slot(name_,idx_,offset_,a,b,c,dont_cache)
    return with_cell_store(name_,
                           function(cdb_,sid_)
                             -- trying to access one past the cdb size is interpreted as
                             -- setting the latest index
                             if idx_==cdb_.size() then
                               return latest(name_,a)
                             end

                             if not dont_cache then
                               local cached = seq_cache[name_]
                               if cached then
                                 cached[idx_+1] = {a,b,c}
                               end
                             end

                             local t,u,v = set_slot(cdb_.read(sid_,idx_),0,offset_,a,b,c)
                             cdb_.write(sid_,idx_,t..u..v)

                             -- save all the files every SAVE_PERIOD
                             if not last_save or time_now()>last_save+SAVE_PERIOD then
                               last_save = time_now()
                               save_all(true)
                             end
                           end
    )
  end


  local function out(key_)
    dirty = true
    if seq_cache[key_] then
      seq_cache[key_] = nil
      seq_cache_size = seq_cache_size - 1
    end

    cell_store_per_name_cache[key_] = nil
    local t = index:delete(key_)
    index:find("metadata=column_db_deleted").count = index:find("metadata=column_db_deleted").count + 1
    return t
  end

  local function cache(name_)
    if seq_cache[name_] then
      return
    end

    return with_cell_store(name_,
                           function(cdb_,sid_)
                             if seq_cache_size==MAX_CACHE_SIZE then
                               local first_name,_ = next(seq_cache)
                               logi("seq_cache is of maximum size. dropping",first_name)
                               seq_cache[first_name] = nil
                               seq_cache_size = seq_cache_size - 1
                               collectgarbage()
                             end
                             local cached = {}
                             local insert = table.insert
                             for idx=0,cdb_.size()-1 do
                               local slot = cdb_.read(sid_,idx)
                               local a,b,c = get_slot(slot,0)
                               insert(cached,{a,b,c})
                             end
                             seq_cache[name_] = cached
                             seq_cache_size = seq_cache_size + 1
                           end
    )

  end

  if not file_exists(meta_file) then
    os.execute("mkdir -p "..base_dir_.." &> /dev/null")
  end

  read_meta_file()
  if not index:find("metadata=column_db_deleted") then
    local n = index:insert("metadata=column_db_deleted")
    n.count = 0
  end

  logi("column_db size",index:size())
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
    create_node = create_node,
    find_keys = find_keys,
    has_sub_keys = has_sub_keys,
    matching_keys = matching_keys,
    flush_cache = function() end,
    cache = function(name_) return cache(name_) end,
    set_increment = function(increment_) _increment = increment_ end,
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
      cache = function(name_) return self.cache(name_) end,
      reset = function() logw("column_db - reset",name_) end,
    }
  end

  return self
end

return {
  cell_store = cell_store,
  column_db = column_db
}
