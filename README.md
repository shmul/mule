# General

Mule is an RRD tool designed with simplicity of use in mind. Its main use case is applicative monitoring.

* metrics need not be declared in advance - simple patterns define families of metrics.
* simple input format
* can keep multiple sequences for the same metric with different retention settings.
* metrics are organized in hierarchies. Sequences of parent nodes are automatically updated when their children are.
* JSON interface which can be used for graph generation and threshold monitoring (by tools like nagios).

# Definitions

* retention pair: `<step,period>`, e.g. `1h:30d`
* metric - a (logical) name *without* any retention data, e.g. `beer.stout.irish`
* event - a trio `<name,value,timestamp>` - input to the database
* sequence - list of slots, identified by a triple `<metric,step,period>`. These are managed by mule
* name - a trio `<metric,step,period>`, e.g. `beer.stout:1h:30d`.
* factory - names (i.e. a trio) that are used for the configuration

# Usage

## Configuration format

The configuration uses one line per metric in the form of

    <metric> <list-of-retentions>

e.g.

    beer.stout 60s:12h 1h:30d


A line can include multiple retentions. Also the same pattern can appear in multiple lines.

### metric

* can be any lua string
* every dot delimited prefix is also a metric, i.e. `beer.stout.irish.dublin` , generates the following:
    * `beer`
    * `beer.stout`
    * `beer.stout.irish`
    * `beer.stout.irish.dublin`
* the most specific match for every metric is used to create the retention sequences for it

#### retention units
* `s` - sec
* `m` - min
* `h` - hour
* `d` - day
* `w` - week
* `m` - month (30 days)
* `y` - year (365 days)


#### Input format
Each line is of the form

    <metric> <value> <timestamp>

or

    .<command> ...

e.g.

    beer.stout.irish 20 74857843
impling 20 orders of `beer.stout.irish` in the given timestamp (measured in seconds - aka unix time). The value (i.e. 20) is usually added to the number already calculated for this timestamp, but if an equal sign `=` precends the value then it replaces the number rather than adding to it.
e.g.

    beer.stout.irish =32 74858041

and

    .gc beer.stout 7489826
runs the garabge-collection command for any metric with the prefix `beer.stout` that wasn't updated after the provided timestamp.


### Commands
* `key <metric>` - retrieve all the metrics for which the given parameter is a prefix. Metric can be an exact sequence name
* `graph <metric> [<timestamp>]` - retrieve all the sequences for which the given parameter is a prefix. Metric can be an exact sequence name. `<timestamp>` can be used to limit the output to a range. In fact `<timestamp>` can be an array (comma separated) of timestamps. Additionally, `l` (latest) and `n` (now) can be used as well as simple arithmatic operations. For example `<timestamp>` can be `l-10..l,n,n-100..l+50` .
* `latest <metric-or-name>` - retrieves the latest updated slot.
* `slot <metric-or-name> <timestamp>` - retrieves the slots specified by the timestamp(s).
* `gc <metric> <timestamp> [<force>]` - erase all metrics that weren't updated since timestamp. Must pass `true` for `<force>` in order to actually modify the DB.
* `reset <metric>` - clear all slots in the metric


### http interface

Mule exposes a REST/JSON interface . Results are return using either plain JSON or as JSONP style, when the generic query string option `p=<callback>` is provided

#### Configuration
To update mule's configuration POST a configuration file to

    http://muleserver/config

To read (export) the configuration GET

    http://muleserver/config

#### Graphs

##### Retrieve graph data
Use a GET request

    http://muleserver/graph/<metric-or-name>?<timestamps>|<level>|<alerts>

* metric-or-name is a metric or a name (i.e. including the retention data). If the metric is used then all the graphs for the metric will be returned, i.e. the graphs for all the names for which the metric is a prefix.
* query string parameters are
  * `timestamps` - the graph data will be restricted to the given timestamps. Timestamps can be a comma separated list of seconds or simple arithmetic expressions using the predefined variables `now` (or `n`) and `latest` (or `l`), like `l-10s`, `now-20d` .
  * `alerts` - if set to true, the alerts status will be added to the names for which alerts are defined.
  * `level` - an optional number of sub key levels to retrieve. Each dot counts for one level. Default level is 1. If no retention pair is provided all the sub keys and their retention pairs are returned. If a retention pair is provided, then only the sub keys with the same retention pairs are returned.
  * `filter` - can be set to `now` or `latest`. If `now`, only results in the time period of `now-period`..`now` will be returned. Similarly with `latest` which filters according to the latest time at which the sequence was updated.

    http://muleserver/graph/<metric-or-name>?<timestamps>


An output example. Each tuple is <value,hits,timestamp>

```json
mule_graph({"version": 3,
"data": {
"wine.pinotage.south_africa;1d:3y": [[4,3,1293753600]]
"wine.pinotage;1d:3y": [[7,5,1293753600]],
"wine.pinotage;1h:30d": [[2,1,1293832800],[5,4,1293836400]],
"wine.pinotage;5m:2d": [[2,1,1293836100],[2,1,1293836400],[3,1,1293837000]],
"alerts": {"wine.pinotage;1h:30d": [34,100,800,900,86400,172800,0,"stale"]}
}
})
```

Multiple metrics (or names) can be use by separating them with `/`, i.e.

    http://muleserver/graph/<metric>


##### Update graph
Use a POST request

    http://muleserver/graph

or (for compatibility with older versions)

    http://muleserver/update

The contents of the file are lines in the format described in the *input* section
    <metric> <value> <timestamp>

#### Metrics hierarchy
The metrics and names create a hierarchy which can be retrieved by sending a GET request to

    http://muleserver/key/<metric>?<level>

* `metric` - Returns all the names for which metric is a prefix.
* `level` - an optional number of sub key levels to retrieve. Each dot counts for one level. Default level is 1. If no retention pair is provided all the sub keys and their retention pairs are returned. If a retention pair is provided, then only the sub keys with the same retention pairs are returned.

Example output (`level=1`)

```json
mule_keys({"version": 3,
"data": {"beer.ale;1d:3y": { "children": true },"beer.ale.pale;1h:30d": { },"beer.ale.pale;1d:3y": { },"beer.ale.pale;5m:2d": { },"beer.ale;1h:30d": { "children": true },"beer.ale;5m:2d": { "children": true }}
})
```

Multiple metrics can be use by separating them with `/`, i.e.

    http://muleserver/key/<metric_1>/<metric_2>/.../<metric_n>

#### Access to specific slots
Data of specific slots can be retrieved by sending a GET request to

    http://muleserver/slot/<metric-or-name>?<timestamps>

The timestamps (as described in the `graph` section) are not optional. Multiple values can be passed (as a list).

Retrieving only the latest updated slot is supported via

    http://muleserver/latest/<metric-or-name>

Both of these requests may use multiple metrics separated by `/`.

#### stop

    http://muleserver/stop?password=<pwd>

Simply stops the running http deamon. This is not meant to be secure by any mean and serves as a simple protection from accidental termination.

#### backup

    http://muleserver/backup

Creates a backup of the db next to it. Returns the path.



## Install

### Lua and luarocks

* install either lua 5.1 or 5.2, preferably using your standard package manager. Alternatively installation [from source](http://www.lua.org/download.html) is also very simple.
* luarocks should also be installed using the package manager or (from source)[http://luarocks.org/en/Download].
* install additional rocks - copas, lpack, luaposix, StackTracePlus (optional)

### Kyotocabinet (or tokyocabinet)

We need either of them plus their lua interface. They can be installed using your favorite package manager or [from source](http://fallabs.com/kyotocabinet/pkg/) and [the lua interface](http://fallabs.com/kyotocabinet/luapkg/). For example here are the steps for Kyotocabinet

#### Kyotocabinet

<pre>
curl http://fallabs.com/kyotocabinet/pkg/kyotocabinet-1.2.76.tar.gz | tar zx
cd kyotocabinet-1.2.76/
configure
make
sudo make install
</pre>

#### Kyotocabinet-lua

<pre>
curl http://fallabs.com/kyotocabinet/luapkg/kyotocabinet-lua-1.28.tar.gz | tar zx
cd kyotocabinet-lua-1.28
configure
make
sudo make install
</pre>

#### NOTES from my Mac compilation:

* `-ldl` was manually added to the config file.
* _maybe_ `-llua` should be removed and only added to the test. Here is the diff
<pre>
--- Makefile	2012-09-10 14:04:41.029239588 +0000
+++ Makefile.mod	2012-09-10 14:04:28.956239462 +0000
@@ -36,8 +36,8 @@
CXX = g++
CPPFLAGS = -I. -I$(INCLUDEDIR) -I/home/ec2-user/include -I/usr/local/include -DNDEBUG -I/usr/include/lua5.1 -I/usr/local/include/lua5.1 -I/usr/include/lua -I/usr/local/include/lua -I/usr/local/include
CXXFLAGS = -march=native -Wall -fPIC -fsigned-char -O2
-LDFLAGS = -L. -L$(LIBDIR) -L/home/ec2-user/lib -L/usr/local/lib -L/usr/lib/lua5.1 -L/usr/local/lib/lua5.1 -L/usr/lib/lua -L/usr/local/lib/lua -L/usr/local/lib
-LIBS = -llua -lkyotocabinet -lz -lstdc++ -lrt -lpthread -lm -lc
+LDFLAGS = -ldl -L. -L$(LIBDIR) -L/home/ec2-user/lib -L/usr/local/lib -L/usr/lib/lua5.1 -L/usr/local/lib/lua5.1 -L/usr/lib/lua -L/usr/local/lib/lua -L/usr/local/lib
+LIBS = -lkyotocabinet -lz -lstdc++ -lrt -lpthread -lm -lc
LDENV = LD_RUN_PATH=/lib:/usr/lib:$(LIBDIR):$(HOME)/lib:/usr/local/lib:$(LIBDIR):/usr/local/lib:.
RUNENV = LD_LIBRARY_PATH=.:/lib:/usr/lib:$(LIBDIR):$(HOME)/lib:/usr/local/lib:$(LIBDIR):/usr/local/lib

@@ -179,7 +179,7 @@


kcmttest : kcmttest.o
-	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS) $(LIBS)
+	$(CXX) $(CXXFLAGS) -o $@ $< $(LDFLAGS) $(LIBS) -llua

</pre>

* `LD_LIBRARY_PATH` should be extended on 64bit machines to point into `/usr/local/lib` (or change the make to `/usr/lib64`)


## usage

### HTTP daemon

Mule ships with a simple HTTP daemon and a support for:
* a REST/JSONP interface
* (naive) static files serving

Since mule is assumed to be an internal application no attempt to make the daemon full feature was made. It is recommended to place an industry level HTTP server/proxy in front of it.

To run mule as an HTTP daemon

    lua mule.lua -d <db-path> -t <bind-address>:<port> [-x <stop-password>] [-l <log-path>] [-R <static-files-root-path>]

for example

    lua mule.lua -d mule.kct -t localhost:3012 -x stopme


TODO provide nginx proxying configuration

### Muleview

Mule ships with a simple [Ext JS](http://www.sencha.com/products/extjs/)-based client web-application written in [CoffeeScript](http://coffeescript.org/) called "Muleview".
Muleview can display graphs of all of Mule's current data.

#### Requirements
Muleview requires [CoffeeScript](http://coffeescript.org/) For compilation and [Sencha Cmd](http://www.sencha.com/products/sencha-cmd/download) for creating a production-ready build (a single-file minified version of the entire framework + source (all_classes.js) and all the necessary static resources).

#### Build
To build a produciton-ready folder:
1. Install [CoffeeScript](http://coffeescript.org/#installation) and make sure the `coffee` command is available
1. Install [Sencha Cmd](http://www.sencha.com/products/sencha-cmd/download) (This will require some additional 3rd parties such as Java and Compass)
1. `cd muleview` and run `sencha app bulid`
1. The output should be generated under muleview/build/Muleview/production

#### Built-in Serving with Mule
You can use Mule itself as a web-server for Muleview. To do so, run Mule with the static files root path parameter (`-R muleview/build/Muleview/production`).
A typical confiugration would be something like:
`lua mule.lua -d db/my_great_db_cdb -T myserver:80 -R muleview/build/Muleview/production`

If you run Mule and Muleview on different servers (and you should), you need to tell Muleview what's Mule's url. This is done in muleview/coffee/app/Settings.coffee . Needless to say, you should set this setting prior to compiling/buidling Muleview.

### CLI

Mule also has a command line interface which is useful for tests (and development), but less so for an interactive use. Run `lua mule.lua -h` for a (terse) usage description.

TODO provide a list of the common commands


### Vagrant box
Mule ships with a [Vagrant](http://vagrantup.com) box for development.
To setup the box:
1. Install vagrant
1. `cd vagrant`
1. `vagrant up`
1. `vagrant ssh`
1. /vagrant/setup.sh
This should setup a machine with all the relevant development dependencies + an Nginx server accessible from the your host @ localhost:3000/mule/
# License

Mule is distributed under the MIT license reproduced below. Mule uses several 3rd party modules whose licenses are described below

## MIT License
Copyright (c) 2012 Trusteer Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Tokyo Cabinet
Tokyo Cabinet is distributed under the "GNU Lesser General Public License".

## Kyoto Cabinet
Kyoto Cabinet is distributed under the "GNU General Public License".

## Lunit
Lunit is licensed under the terms of the MIT license. [Lunit home page](http://www.nessie.de/mroth/lunit/)

## Copas
Copas of the Kepler project is used and is disributed under [this license](http://keplerproject.github.com/copas/license.html). Copyright (c) 2005-2010 Kepler Project.

## lpack
[lpack](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lpack) is used.

## luaposix
[luaposix](https://github.com/luaposix/luaposix) is used.
