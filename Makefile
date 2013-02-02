all: dan_cbd run

dan_cbd:
	lua mule.lua -v -d dan_cdb -c dan.cfg -r -f

run:
	lua mule.lua -v -d dan_cdb -c dan.cfg -t localhost:3000

clean:
	rm -rf dan_cdb 

.PHONY: clean run
