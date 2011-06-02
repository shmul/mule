= Mule

== General
An RRD library, which shamelessly borrows from [[ http://graphite.wikidot.com/ | graphite]]
* metrics need not be declared in advance - simple patterns define families of metrics
* can keep multiple sequences for the same metric
* can aggregate data for the metrics families
* hooks can be added to:
  * watch for changes in values
  * compare with past values
  
== Configuration format
The configuration uses one line per metric in the form of 

  <metric-pattern> <list-of-retentions>

e.g.

  event.phishing 60s:12h 1h:30d


A line can include multiple retentions. Also the same pattern can appear in multiple lines.

=== metric-pattern
* can be any lua string
* every dot delimited prefix is also a metric, i.e. event.phishing.google.com , generates the following:
** event
** event.phishing
** event.phishing.google
** event.phishing.google.com
* the most specific match for every metric is used to create the retention sequences for it

=== retention units 
  * ((%s%)) - sec
  * ((%m%)) - min
  * ((%h%)) - hour
  * ((%d%)) - day
  * ((%w%)) - week
  * ((%m%)) - month (30 days)
  * ((%y%)) - year (365 days)


== Input format
Each line is of the form

  <metric> <value> <time-stamp>(unix epoch) [time format]

or

  .<command> ...

e.g.

  event.phishing.phishing-host 20 74857843
  .gc event.phishing 7489826

impling 20 accesses to the ((%phishing-host%)) in the given timestamp.

=== Commands
* ((%reset <metric>%))) - clear all slots in the metric
* ((%stdout <metric>%)) - outputs a sorted metric to stdout
* ((%gc <metric> <timestamp>%)) - erase all metrics who haven't changed since timestamp

== Data Procesing
Every metric is inited so all of its slots are empty

* every line is added to all the sequences that were defined for the matching metrics
* each sequence calculates the slot into which it fits
* the value is added to the data in the slot and the number of additions to the slot is incremented (to facilitate average calculations)

=== Implementation
==== Choosing the slot
Every slot contains:
* timestamp - last time the slot was updated. The timestamp is always adjusted to the ((|beginning|)) of slot.
* value - sum of values associated with the slot 
* hits - number of updates (to calculate averages)

The slot is reset whenever it should be updated, but the difference between the slot's timestamp and the new timestamp is larger than the step.

==== Data structures
A list of patterns is kept. For every input line, the metric is checked against the patterns and when a match is found, a new sequence is created (if required). Each metric keeps a list of its sequences.

Caching is implemented per metric to avoid re-scanning the entire patterns list per line. It saves all the matching patterns for this metric. It is invalidated when the configuration is re-read or when gc runs.



== Output format
Each metric outputs its values starting from the current slot + 1 until it reach current slot again. Null slots are not outputed. The format is

  <metric-name>, <value>, <average>, <first-access>(unix epoch)


=== Open issues ===
  - how do we optimize the metrics match? If we use just prefixes, we can use a trie.