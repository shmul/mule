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

if ! which rvm
then
  : Installing RVM, Ruby:
  : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  curl -L https://get.rvm.io | HOME=/home/vagrant bash -ls stable --ruby=1.9.3 --verify-downloads 1
fi

: Setting up Nginx
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

source_nginx_conf="/vagrant/mule_nginx.conf"
target_nginx_conf="/etc/nginx/sites-enabled/mule_nginx.conf"

if ! [ -L $target_nginx_conf ]
then
  sudo ln -s $source_nginx_conf $target_nginx_conf
fi
sudo service nginx restart
