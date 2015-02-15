#!/bin/bash
set -x
set -e

: Set locale:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo locale-gen UTF-8 || :

: Installing packages:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
if ! which curl
then
  sudo apt-get update -y
fi
sudo apt-get install -y lua5.1 luarocks nginx

: Installing rocks:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo luarocks install copas 1.1.6-1
sudo luarocks install lpack
sudo luarocks install luaposix

# TODO:
# - Add upstart / system[d,x] configuraiton for mule
# - Apply nginx configuration
