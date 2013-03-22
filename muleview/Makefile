all:
	coffee -o ./ -c coffee

coffee:
	coffee -o ./ -cw coffee/

timestamp:
	while [ 1 ]; do rake timestamp_keys; sleep 5; done

.PHONY: coffee
