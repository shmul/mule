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
sudo apt-get install -y lua5.1 luarocks nginx git

: Installing Lightningmdb:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
mkdir installs
pushd installs
git clone https://gitorious.org/mdb/mdb.git
cd mdb/libraries/liblmdb/
make
sudo make install
sudo ldconfig # we need to rebuild the cache to have libmdb.so discoverable
popd

: Installing rocks:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo luarocks install copas 1.1.6-1
sudo luarocks install lpack
sudo luarocks install luaposix
sudo luarocks install bitlib
sudo luarocks install lightningmdb

# TODO:
# - Add upstart / system[d,x] configuraiton for mule
# - Apply nginx configuration
