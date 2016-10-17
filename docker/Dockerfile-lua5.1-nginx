FROM ubuntu:14.04

RUN apt-get update -y && apt-get install -y unzip curl make git


RUN apt-get install -y lua5.1 liblua5.1 liblua5.1-dev

# Install luarocks
RUN cd /tmp && \
    curl -L -O http://luarocks.org/releases/luarocks-2.2.1.tar.gz && \
    tar zxpf luarocks-2.2.1.tar.gz && \
    rm luarocks-2.2.1.tar.gz && \
    cd luarocks-2.2.1 && \
    ./configure --prefix=/usr && \
    make bootstrap && \
    cd /tmp && \
    rm -r /tmp/luarocks-2.2.1

RUN cd /tmp && \
    curl -L -O https://github.com/LMDB/lmdb/archive/LMDB_0.9.15.tar.gz && \
    tar -xzf LMDB_0.9.15.tar.gz && \
    rm LMDB_0.9.15.tar.gz && \
    cd lmdb-LMDB_0.9.15/libraries/liblmdb && \
    make all install && \
    ldconfig && \
    cd /tmp && \
    rm -r /tmp/lmdb-LMDB_0.9.15

RUN luarocks install bit32
RUN luarocks install copas 1.1.6-1
RUN luarocks install lightningmdb
RUN luarocks install luaposix
RUN luarocks install lsqlite3
RUN luarocks install xxhash

RUN apt-get install -y nginx-extras
RUN apt-get install -y vim

ENV HOME /root
WORKDIR $HOME

COPY *.lua $HOME/
COPY lunit-0.5 $HOME/lunit-0.5
COPY tests $HOME/tests
COPY fdi $HOME/fdi/
COPY scent $HOME/scent
COPY muleview $HOME/muleview
COPY docker/nginx.mule.conf $HOME/

RUN ln -s /root/nginx.mule.conf /etc/nginx/sites-enabled/mule
RUN mkdir -p /root/queues/mule_incoming
RUN mkdir -p /root/queues/mule_processed
RUN mkdir -p /root/queues/mule_work
RUN chmod o+rw /root/queues/*
RUN chown www-data scent muleview
RUN chmod u+x scent muleview
RUN chmod o+x /root

RUN mkdir -p $HOME/tests/temp
