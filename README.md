# General

Mule is a RRD tool designed with simplicity of use in mind. Its main use case is applicative monitoring.

* metrics need not be declared in advance - simple patterns define families of metrics.
* simple input format
* can keep multiple sequences for the same metric with different retention settings.
* metrics are organized in hierarchies. Sequences of parent nodes are automatically updated when their childs are.
* JSON interface which can be used for graph generation and threshold monitoring (by tools like nagios).

# License

Mule is distirbtued under the MIT license reproduced below. Mule uses several 3rd party modules whose licenses are described below

## MIT License
Copyright (c) 2012> Trusteer Ltd.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Tokyo Cabinet
Tokyo Cabinet is distirbtued under the "GNU Lesser General Public License".

## Kyoto Cabinet
Kyoto Cabinet is distirbtued under the "GNU General Public License".

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
impling 20 accesses to the `irish` in the given timestamp.

and

    .gc beer.stout 7489826
runs the garabge-collection command for any metric with the prefix `beer.stout` that wasn't updated after the provided timestamp.


### Commands
* `key <metric>` - retrieve all the metrics for which the given parameter is a prefix. Metric can be an exact sequence name
* `graph <metric> [<timestamp>]` - retrieve all the sequences for which the given parameter is a prefix. Metric can be an exact sequence name. `<timestamp>` can be used to limit the output to a range. In fact `<timestamp>` can be an array (comma separated) of timestamps. Additionally, `l` (latest) and `n` (now) can be used as well as simple arithmatic operations. For example `<timestamp>` can be `l-10..l,n,n-100..l+50` .
* `piechart <metric>` - TODO
* `latest <metric>` - TODO
* `slot <metric>` - TODO
* `gc <metric> <timestamp> [<force>]` - erase all metrics that weren't updated since timestamp. Must pass `true` for `<force>` in order to actually modify the DB.
* `reset <metric>` - clear all slots in the metric


### http interface

Mule exposes a REST/JSON interface . Results are return using either plain JSON or as JSONP style, when the generic query string option `p=<callback>` is provided

#### graph

    http://muleserver/graph/<metric-or-name>?<timestamps>

Returns the graph, where metric-or-name is a metric or a name (i.e. including the retention data). If the metric is used then all the graphs for the metric will be returned, i.e. the graphs for all the names for which the metric is a prefix.

timestamps are optional, but if present, the graph data will be restricted to the given timestamps. Timestamps can be a comma separated list of:
* seconds
* simple arithmetic expressions using the predefined variables 'now' (or 'n') and 'latest' (or 'l'), like 'l-10s', 'now-20d'

An output example. Each tuple is <value,hits,timestamp>

```json
mule_graph({"version": 3,
"data": {"wine.pinotage.south_africa;1d:3y": [[4,3,1293753600]]
,"wine.pinotage;1d:3y": [,[7,5,1293753600]]
,"wine.pinotage;1h:30d": [,[2,1,1293832800],[5,4,1293836400]]
,"wine.pinotage;5m:2d": [,[2,1,1293836100],[2,1,1293836400],[3,1,1293837000]]
}
})
```

#### key

    http://muleserver/graph/<metric>

Returns all the names for which metric is a prefix. Example output is

```json
mule_keys({"version": 3,
"data": ["wine.pinotage.south_africa;1d:3y","wine.pinotage.south_africa;1h:30d","wine.pinotage.south_africa;5m:2d","wine.pinotage.brazil;1d:3y","wine.pinotage.brazil;1h:30d","wine.pinotage.brazil;5m:2d","wine.pinotage.canada;1d:3y","wine.pinotage.canada;1h:30d","wine.pinotage.canada;5m:2d","wine.pinotage.us;1d:3y","wine.pinotage.us;1h:30d","wine.pinotage.us;5m:2d","wine.pinotage;1d:3y","wine.pinotage;1h:30d","wine.pinotage;5m:2d"]
})
```

#### stop

    http://muleserver/stop?password=<pwd>

Simply stops the running http deamon. This is not meant to be secured by any mean.

TODO - more commands

## Install

### Lua and luarocks

* install either lua 5.1 or 5.2, preferably using your standard package manager. Alternatively installation [from source](http://www.lua.org/download.html) is also very simple.
* luarocks should also be installed using the package manager or (from source)[http://luarocks.org/en/Download].
* install additional rocks - copas

### Kyotocabinet (or tokyocabinet)

We need either of them plus their lua interface. They can be installed using your favorite package manager or [from source](http://fallabs.com/kyotocabinet/pkg/) and [the lua interface](http://fallabs.com/kyotocabinet/luapkg/). For example here are the steps for Kyotocabinet

#### Kyotocabinet

<pre>
curl http://fallabs.com/kyotocabinet/pkg/kyotocabinet-1.2.76.tar.gz | tar zx
cd kyotocabinet-1.2.76/
configure
make
sudo make install
</pre<

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

Mule ships with a simple HTTP daemon with a REST/JSONP interface. Since mule is assumed to be an internal application no attempt to make the daemon full feature was made. It is recommended to place an industry level HTTP server/proxy in front of it.

To run mule as an HTTP daemon

    lua mule.lua -d <db-path> -t <bind-address>:<port> [-x <stop-password>] [-l <log-path>]

for example

    lua mule.lua -d mule.kct -t localhost:3012 -x stopme


TODO provide nginx proxying configuration

### CLI

Mule also has a command line interface which is useful for tests (and development), but less so for an interactive use. Run `lua mule.lua -h` for a (terse) usage description.

TODO provide a list of the common commands