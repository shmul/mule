#!/bin/bash
set -x
set -e

: Set locale:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo locale-gen UTF-8 || :

: Installing packages:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo apt-get update -y
sudo apt-get install -y curl python-software-properties python g++ make unzip lua5.1 luarocks wget software-properties-common openjdk-6-jre nginx git autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm3 libgdbm-dev

if [ ! -f /usr/local/lib/liblmdb.so ]
then
: Installing Lightningmdb:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  mkdir -p ~/installs
  pushd ~/installs
  git clone https://gitorious.org/mdb/mdb.git
  cd mdb/libraries/liblmdb/
  make
  sudo make install
  sudo ldconfig # we need to rebuild the cache to have libmdb.so discoverable
  popd
fi;


: Installing rocks:
: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
sudo luarocks install copas 1.1.6-1
sudo luarocks install lpack
sudo luarocks install luaposix
sudo luarocks install bitlib
sudo luarocks install lightningmdb

if ! which npm
then
  : Installing nodejs, coffee-script:
  : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  sudo add-apt-repository ppa:chris-lea/node.js -y
  sudo apt-get update -y
  sudo apt-get install -y nodejs
  sudo npm install -g coffee-script@1.6.2
fi

if [ ! -e ~/.rbenv ]
then
  git clone https://github.com/sstephenson/rbenv.git ~/.rbenv
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
  echo 'eval "$(rbenv init -)"' >> ~/.bash_profile

  mkdir -p ~/ruby-build
  pushd ~/ruby-build
  git clone https://github.com/sstephenson/ruby-build.git .
  sudo ./install.sh
  rbenv install 2.2.0
  rbenv global 2.2.0
  popd

  source ~/.bash_profile
fi

if ! which sencha
then
  : Installing Sencha cmd:
  : ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  pushd /tmp
  rm -f SenchaCmd-3.1.2.342-linux-x64.run.zip SenchaCmd-3.1.2.342-linux-x64.run
  wget http://cdn.sencha.com/cmd/3.1.2.342/SenchaCmd-3.1.2.342-linux-x64.run.zip
  unzip SenchaCmd-3.1.2.342-linux-x64.run.zip
  chmod +x SenchaCmd-3.1.2.342-linux-x64.run
  bash -l -c "/tmp/SenchaCmd-3.1.2.342-linux-x64.run --mode unattended"
  popd
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
