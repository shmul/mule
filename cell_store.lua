require "helpers"


-- row - every name/metric is a row
-- column - the slot index

function cell_store(file_,num_rows_,num_columns_,cell_size_)
  local file = nil
  local dirty = false

  local function reset()
    local cmd = string.format("dd if=/dev/zero of=%s bs=%d count=%d &> /dev/null",file_,num_rows_*num_columns_,cell_size_)
    logi("creating file",file_)
    os.execute(cmd)
  end

  if not file_exists(file_) then
    reset()
  end

  file = io.open(file_,"r+b") --or io.open(file_,"w+b")
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
      logd("flush",file_)
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
    logd("seek",file_,cell_pos)
    file:seek("set",cell_pos)
    return true
  end

  local function read_cell(row_,column_)
    flush()
    if seek(row_,column_) then
      return file:read(cell_size_)
    end
  end

  local function write_cell(row_,column_,cell_)
    if seek(row_,column_) then
      dirty = true
      return file:write(string.sub(cell_,1,cell_size_))
    end
  end

  local function write_cells(row_,column_,values_)
    if seek(row_,column_) then
      local sub = string.sub
      for _,v in ipairs(values_) do
        file:write(sub(v,1,cell_size_))
      end
      dirty = true
    end
  end

  return {
    close = close,
    flush = flush,
    read = read_cell,
    write = write_cell,
    write_cells = write_cells,
         }
end