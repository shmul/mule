module("column_db",package.seeall)
require "helpers"

local _,p = pcall(require,"purepack")
local _,sl = pcall(require,"skiplist")

COLUMN_DB_PER_FILE = 200
function column_db(base_dir_)
  local index = sl:new(NUMBER_OF_KEYS)
  local meta_file = base_dir_.."/db.meta"
  local metric_files = {}



  with_file(meta_file,
            function(f_)
              index = p.unpack(f_:read("*a"))
            end,"r+b")


  local function extract_from_name(name_)
    local node = index[name_]

    if not node then
      local metric,step,period = split_name(name_)
      node = index:insert(name_)
      node.metric = metric
      node.step = step
      node.period = period
    end
    return node.metric,node.step,node.period,node.value
  end

  local function find_file(name_)
    local metric,step,period,id = extract_from_name(name_)
    -- we normalize the step,period variables to canonical time units
    return string.format("%s/%s.%s.%d.cdb",base_dir_,
                         secs_to_time_unit(step),
                         secs_to_time_unit(period),
                         id / COLUMN_DB_PER_FILE),period/step,id % COLUMN_DB_PER_FILE
  end

  local function with_cell_db(name_,func_)
  -- TODO add open cell_db cache
    local filename,num_rows,row = find_file(name_)
    local cdb = cell_store(filename,size,18) -- 3 items per slot, 6 bytes per one
    -- TODO it is preferable to use pcall and to close/flush (or something) when
    -- the func returns. However, it can doesn't play well with multiple return values
    -- from func_
    return func_(cdb,row)
  end

  local function save()
    with_file(meta_file,
            function(f_)
              f:write(p.pack(index))
            end,"w+b")
    -- TODO save all files
  end

  local function put(key_,value_)
    local node = index:find(key_)
    local is_metadata = string.find(key_,"metadata=",1,true)

    -- value is updated only for metadata nodes
    if not node then
      node = index:insert(key_)
      -- to all non metadata keys we assign a global id. This id is used for storing
      -- the actual sequences
      if not is_metadata then
        index.head.id = index.head.id + 1
        node.value = index.head.id
      end
    end
    if is_metadata then
      node.value = value_
    else
      -- TODO - find the file for the key (graph) and update the content with the
      -- value
    end
  end

  local function get(key_)
    local node = index[key_]

    if string.find(key_,"metadata=",1,true) then
      return node.value
    end

    -- TODO - find the file for the key (graph) and return all of its data

  end

  local function out(key_)
    return index:delete(key_)
  end

  local function matching_keys(prefix_)
    return coroutine.wrap(
      function()
        local find = string.find
        local node = sl:find(prefix_)
        -- first node may not match the prefix as it the largest element <= prefix_
        if node.key<prefix_ then
          node = sl:next(node)
        end
        while node and node.key and find(node.key,prefix_,1,true) do
          coroutine.yield(node)
          node = sl:next(node)
        end
      end)
  end

  local function internal_get_cell(name_,idx_,offset_)
    return with_cell_db(name_,function(cdb,row)
                          local cell = cdb.read(row,idx_)
                          local a,b,c = get_slot(cell,idx_,offset_)
                          release_cell_db(cdb)
                          return a,b,c
                       )
  end

  local function internal_set_cell(name_idx_,offset_,a,b,c)
    return with_cell_db(name_,function(cdb,row)
                          local cell = set_slot(cdb.read(row,idx_),idx_,offset_,a,b,c)
                          cdb.write(idx_,row,cell)
                       )
  end

  local self = {
    save = save,
    put = put,
    get = get,
    out = out,
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
    end
  }

  self.sequence_storage = function(name_,numslots_)
    return sequence_storage(self,name_,numslots_)
  end

  return self
end
