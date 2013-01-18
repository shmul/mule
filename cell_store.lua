require "helpers"

function cell_store(file_,num_rows_,cell_size_)
  local file = nil
  local dirty = false

  file = io.open(file_,"r+b") or io.open(file_,"w+b")
  if not file then
    loge("unable to open column store",file_)
    return nil
  end

  logd("opened column store",file_)

  local function close()
    if file then
      logd("closed column store",file_)
      file:close()
    end
  end

  local function flush()
    if file and dirty then
      file:flush()
      dirty = false
    end
  end

  -- zero based
  local function seek(row_,column_)
    if not file then
      logw("no file")
      return nil
    end
    local cell_pos = cell_size_*(num_rows_*column_+row_)
    file:seek("set",cell_pos)
    return true
  end

  local function read_cell(row_,column_)
    if seek(row_,column_) then
      return file:read(cell_size_)
    end
  end

  local function write_cell(row_,column_,cell_)
    if seek(row_,column_) then
      return file:write(string.sub(cell_,1,cell_size_))
    end
  end

  return {
    close = close,
    flush = flush,
    read = read_cell,
    write = write_cell,
         }
end