NO NEED The summary of alerts can be added to the top bar with their count and a pulldown to see them
NO NEED choosing an item from the alert poll down opens the graph in an overlay with an option to add it to the dashboard
the dashboard will include a rotating list of graphs - one strip for critical and other for anomalies
DONE use the search bar to look for graphs. Choosing a graph opens it in an overlay (http://vast-engineering.github.io/jquery-popup-overlay/)

DONE the left bar can contain a list of recently used graphs and a configurable list of favourites

DONE read the mule config and extract from it the list of possible retention pairs per graph

DONE add a page that gets the graph in the hashtag and displays only it

NO NEED do we need the breadcrumbs

DONE metricsgraphics supports a confidence band that can be used with the new anomalies

support users


DONE for alerts use ~/dev/remotes/AdminLTE/pages/tables/data.html with a page called alert/{critical,warning,anomalies,normal}

DONE implement caching of graphs with expiration based on their retention pair

DONE to the graph pane add links to the sibling graphs
DONE to the graph pane add add to favorites/remove from favorites

NO NEED use https://select2.github.io/examples.html for search

DONE move all the other components to under plugins

support retrieval of multiple graphs by the datasource

add an editor in modal for the dashboards or support drag/drop?

DONE css in the left bar - the padding of the items I generate are messed. I probably mask something by the container I add


chart:
- DONE add the other graphs links
- DONE display an error message if the graph has no data
- when a graph is refereshed add an affect


DONE search over keys should merge the retention pairs until ; is added

DONE search over keys should add a spinner when fetching data

DONE the collaps/close buttons per box don't function. Probably due to the header template

solve the fixed height settings to be more adaptive - see this http://www.minimit.com/articles/solutions-tutorials/bootstrap-3-responsive-columns-of-same-height

NO NEED use zoom in - https://github.com/nvd3-community/nvd3/blob/gh-pages/examples/lineChartSVGResize.html

add sparkline to the alerts tables - http://omnipotent.net/jquery.sparkline/#s-about


DONE thresholds, anomalies and expected

to delete a dashboard - support it from the dashboard main page

DONE after adding a dashboard - move the focus to it.

DONE use data-targets where possible

DONE use data-target instead of href for links (http://getbootstrap.com/javascript/ look for "To keep URLs intact ")

DONE switch to bootbox where possible

NO NEED when clicking a graph in an alert table - scroll to top

a piechart-like implementation.

DONE use nested templates - the all_links and favorites

DONE overcome the extra referesh of the alerts menu by caching the value (or a digest of it) and rendering only if needed

reduce the flickering when switching between the all_links

NO NEED when adding a favorite/recent add a transition to the menu item (if it is opened)

DONE add an indication to the graph header if the graph is in an alert state

add openid (http://jvance.com/pages/jQueryOpenIdPlugin.xhtml)

DONE alerts should be cached and automatically refreshed

DONE I'm not sure the inner navigations highlighting work as expected.

DONE Add loading indication to inner navigation

DONE display favorites, recent,

display api (from Readme)

add copy button to the graphs

DONE layout the top level keys

DONE use a tree? https://github.com/jonmiles/bootstrap-treeview

carousel for alerts? http://www.jssor.com/bootstrap/bootstrap-carousel.html

change the title of the main keys table to reflect the key being browsed. Use bread crumbs or split the top key into elements in order to do navigation.

add a progress indication when navigating the keys table

support annotations over the graph - use the key/value capabilities. Added independently of graphs and displayed over all the graphs based on a toggle.

to highlight the difference between latest and now, artificially add the now timestamp to the graph. This can be done by chaning the filter to "now" instead of the usual "latest"

the metricsgraphics markers (for thresholds) are layed on top of each other.

toggle confidence band