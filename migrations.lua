require "mulelib"

function migrate_0_to_1(db_path_)
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack = generate_fuctions()

  local db = tc_init(db_path_)

  -- metrics#metadata
  local metrics_metadata = tc_get("metrics#metadata")
  local config = strin(metrics_metadata)
  local factories = deserialize_table_of_arrays(config,function(in_)
														 return {in_.read_number(),
																 in_.read_number()}
													   end)
  config = strout()
  config.write_number(1)

  serialize_table_of_arrays(config,factories,function(out_,item_)
											   out_.write_number(item_[1])
											   out_.write_number(item_[2])
											 end)
  tc_put("metrics#metadata",config.get_string())


  -- sequences
  local keys = tc_fwmkeys("")
  for _,k in ipairs(keys) do
	if k~="metrics#metadata" and string.find(k,"#metadata",1,true) then
	  local v = tc_get(k)
	  local step,period = unpack(tc_unpack("NN",v))
	  tc_put(k,tc_pack("NNN",step,period,0))
	end
  end

  
  tc_done()
end


function migrate_1_to_2(db_path_)
  local tc_init,tc_done,tc_get,tc_put,tc_fwmkeys,tc_pack,tc_unpack,tc_out = generate_fuctions()

  local db = tc_init(db_path_)

  -- change the version string of the metrics metadata
  local metrics_metadata = tc_get("metrics#metadata")
  local config = strin(metrics_metadata)
  local config_version = config.read_number()
  if config_version~=1 then
	loge("unexpected version number",config_version)
	return
  end
  logi("changing metadata version")
  local factories = deserialize_table_of_arrays(config,function(in_)
														 return {in_.read_number(),
																 in_.read_number()}
													   end)
  config = strout()
  config.write_number(2)

  serialize_table_of_arrays(config,factories,function(out_,item_)
											   out_.write_number(item_[1])
											   out_.write_number(item_[2])
											 end)
  tc_put("metrics#metadata",config.get_string())

  -- replace all the # in the keys with ;
  for _,k in ipairs(tc_fwmkeys("")) do
	if string.find(k,"#") then
	  local v = tc_get(k)
	  local nk = string.gsub(k,"#",";")
	  logi("replacing",k,nk,#v)
	  tc_out(k)
	  tc_put(nk,v)
	end
  end

  
  tc_done()
end