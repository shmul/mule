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
sudo apt-get install -y curl python-software-properties python g++ make unzip lua5.1 luarocks wget software-properties-common openjdk-6-jre nginx

: Installing rocks:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo luarocks install copas 1.1.6-1
sudo luarocks install lpack
sudo luarocks install luaposix

if ! which npm
then
  : Installing nodejs, coffee-script:
  : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  sudo add-apt-repository ppa:chris-lea/node.js -y
  sudo apt-get update -y
  sudo apt-get install -y nodejs
  sudo npm install -g coffee-script@1.6.2
fi

if ! which rvm
then
  : Installing RVM, Ruby:
  : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  curl -L https://get.rvm.io | HOME=/home/vagrant bash -ls stable --ruby=1.9.3 --verify-downloads 1
fi

if ! which sencha
then
  : Installing Sencha cmd:
  : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  cd /tmp
  rm -f SenchaCmd-3.1.2.342-linux-x64.run.zip SenchaCmd-3.1.2.342-linux-x64.run
  wget http://cdn.sencha.com/cmd/3.1.2.342/SenchaCmd-3.1.2.342-linux-x64.run.zip
  unzip SenchaCmd-3.1.2.342-linux-x64.run.zip
  chmod +x SenchaCmd-3.1.2.342-linux-x64.run
  bash -l -c "/tmp/SenchaCmd-3.1.2.342-linux-x64.run --mode unattended"
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
