all: dan_cdb run

dan_cdb:
	lua mule.lua -v -d dan_cdb -c dan.cfg -r

run:
	cat dan.cfg
	sleep 3
	lua mule.lua -v -d dan_cdb -c dan.cfg -t localhost:3000

clean:
	rm -rf dan_cdb

.PHONY: clean run
