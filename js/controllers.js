function AppCtrl($scope, $state, Alert) {

    $scope.openGraph = function(key, period){
        $state.go("app.graph", {key: key, period: period}, {reload: true})
    }

    Alert.get({}, function(response){
        $scope.alerts = $scope.resolveAlerts(response.data);
    })

    $scope.resolveAlerts = function(raw_data_){
        var alerts = [[],[],[],[],[]];
        for (n in raw_data_) {
            var current = raw_data_[n];
            var idx = $scope.alert_index(current[7]);
            if ( idx>=0 ) {
                alerts[idx].push([n,current]);
            }
        }
            var anomalies = raw_data_["anomalies"];
            for (n in anomalies) {
            alerts[2].push([n,anomalies[n]]);
        }
        return alerts
    }

    $scope.alert_index = function(alert_string_) {
        switch ( alert_string_ ) {
        case "CRITICAL LOW":
        case "CRITICAL HIGH": return 0;
        case "WARNING LOW":
        case "WARNING HIGH": return 1;
        case "stale": return 3;
        case "NORMAL": return 4;
        }
        return -1;
    }

    $scope.map_severity = function(alert_id_) {
        switch ( alert_id_ ) {
        case '0': return {title: "Critical", color: "#ed5565", icon: "fa fa-exclamation-triangle" };
        case '1': return {title: "Warning", color: "#f8ac59", icon: "fa fa-exclamation-circle" };
        case '2': return {title: "Anomaly", color: "#f39c12", icon: "fa fa-info-circle" };
        case '3': return {title: "Stale", color: "#d81b60", icon: "fa fa-check-circle-o" };
        case '4': return {title: "Normal", color: "#00a65a", icon: "fa fa-check-circle" };
        }
        return "Alert";
    }
}

function HomeCtrl($scope, Keys, Graph, $compile, $state, $filter) {

    Keys.get({keyId: ''}, function(response){
        $scope.keys = $scope.resolveKeys(response.data);
    })



    $scope.resolveKeys = function(keys){
        var resolvedKeys = {};

        angular.forEach(keys, function(value, key) {
          k = key.split(';')[0]
          v = key.split(';')[1]

          if (typeof this[k] === 'undefined'){
            this[k] = {}
            this[k]['period'] = [v]
            this[k]['children'] = value
          } else{
            this[k]['period'].push(v)
            this[k]['children'] = value
          }
        }, resolvedKeys);
        return resolvedKeys;
    }

    $scope.getChildrenKeys = function(chosenKey, $event){
        $scope = $scope.$new(false);

        $(event.target).parent().parent().addClass('active')
        $('.table_keys').css('background-color','white');
        $('.selected_key').show();

        if($event.target.className.split(' ')[0] == 'level_0'){
            $('.levels').remove();
            $('.active').css('background-color','white');

        }
        $(event.target).parent().parent().css('background-color','#00EAEC')

        Keys.get({keyId: chosenKey}, function(response){
            var children = $scope.resolveKeys(response.data);
            $scope.getLastKey = function (id){
                s = String(id).split('.')
                return s[s.length - 1]
            }
            $scope.children = children;
            $scope.keysCount = $filter('keylength')(children);
            $scope.chosenKey = chosenKey;
            $('#table_append').append($compile("<div class='col-lg-3 levels' style='display: inline-block;'><h2><b>{{ getLastKey(chosenKey) }} </b> ({{ keysCount - 1}})<span style='float:right'><i class='fa fa-angle-right selected_key' style='display:none;font-size: 30px;color:grey;'></i></span></h2><table class='table table-hover issue-tracker table_keys' style='background-color:#F7F7F7'><tr ng-repeat='(k, v) in children | custom: searchKeys' ng-if='k != chosenKey'><td class='issue-info'><a href='#'>{{ getLastKey(k) }}</a><small>Key Description</small></td><td ng-repeat='period in v.period' ><a href='' ng-click='openGraph(k, period)'><span class='pie' style='display: none;' >0.52,1.041</span><svg class='peity' height='16' width='16'><path d='M 8 8 L 8 0 A 8 8 0 0 1 14.933563796318165 11.990700825968545 Z' fill='#1ab394'></path><path d='M 8 8 L 14.933563796318165 11.990700825968545 A 8 8 0 1 1 7.999999999999998 0 Z' fill='#d7d7d7'></path></svg>{{period}}</a></td><td><a href='#' ng-click='getChildrenKeys(k, $event)'><i class='fa fa-angle-double-right' style='font-size: 23px;color:grey;'></a></td></tr></table></div>")($scope))
        })
    }

    var sparkline1Data = [34, 43, 43, 35, 44, 32, 44, 52];
    var sparkline1Options = {
        type: 'line',
        width: '100%',
        height: '50',
        lineColor: '#1ab394',
        fillColor: "transparent"
    };

    var sparkline2Data = [32, 11, 25, 37, 41, 32, 34, 42];
    var sparkline2Options = {
        type: 'line',
        width: '100%',
        height: '50',
        lineColor: '#1ab394',
        fillColor: "transparent"
    };

    this.sparkline1 = sparkline1Data;
    this.sparkline1Options = sparkline1Options;
    this.sparkline2 = sparkline2Data;
    this.sparkline2Options = sparkline2Options;
}

function GraphCtrl($scope, Keys, Graph, $compile, $stateParams, $interval, $rootScope) {

    $scope.period = $stateParams.period;
    $scope.key = $stateParams.key;
    $scope.currentGraph = resolveKeyJson($stateParams.key, $stateParams.period)
    var graphDataA = [];
    $scope.graphDataAavg = 0;
    var graphDataB = [];
    $scope.graphDataBavg = 0;

    function initGraph(){
        $scope.graph = Graph.get({keyId: $stateParams.key, timeId: $stateParams.period}, function(response){
            $scope.lastUpdate = new Date();
            angular.forEach(response.data[resolveKeyJson($stateParams.key, $stateParams.period)], function(data) {
                graphDataA.push([data[2], data[0]]);
                $scope.graphDataAavg += data[0];
                graphDataB.push([data[2], data[1]]);
                $scope.graphDataBavg += data[1];
            });
            $scope.graphDataAavg /= response.data[resolveKeyJson($stateParams.key, $stateParams.period)].length
            $scope.graphDataBavg /= response.data[resolveKeyJson($stateParams.key, $stateParams.period)].length
        })
    }

    initGraph();

    $interval(initGraph, $rootScope.refreshInterval);


    function resolveKeyJson(key, period){
        return key + ';' + period;
    }

    $scope.multiData = [
        {
            data: graphDataA,
            label: "Metric 1"
        },
        {
            data: graphDataB,
            label: "Metric 2",
            //yaxis: 4
        }
    ];

    $scope.multiOptions = {
        xaxes: [
            {
                mode: 'time'
            }
        ],
        yaxes: [],
        legend: {
            position: 'ne'
        },
        colors: ["#6666EC", "#1ab394"],
        grid: {
            color: "#999999",
            hoverable: true,
            clickable: true,
            tickColor: "#D4D4D4",
            borderWidth: 0

        },
        tooltip: true,
        tooltipOpts: {
            content: "%s - %y",
            xDateFormat: "%y-%0m-%0d",
            onHover: function (flotItem, $tooltipEl) {
            }
        }

    };
}

function DashboardCtrl($scope) {

    var data1 = [
        [0, 4],
        [1, 8],
        [2, 5],
        [3, 10],
        [4, 4],
        [5, 16],
        [6, 5],
        [7, 11],
        [8, 6],
        [9, 11],
        [10, 30],
        [11, 10],
        [12, 13],
        [13, 4],
        [14, 3],
        [15, 3],
        [16, 6]
    ];
    var data2 = [
        [0, 1],
        [1, 0],
        [2, 2],
        [3, 0],
        [4, 1],
        [5, 3],
        [6, 1],
        [7, 5],
        [8, 2],
        [9, 3],
        [10, 2],
        [11, 1],
        [12, 0],
        [13, 2],
        [14, 8],
        [15, 0],
        [16, 0]
    ];

    var options = {
        series: {
            lines: {
                show: false,
                fill: true
            },
            splines: {
                show: true,
                tension: 0.4,
                lineWidth: 1,
                fill: 0.4
            },
            points: {
                radius: 0,
                show: true
            },
            shadowSize: 2,
            grow: {stepMode:"linear",stepDirection:"up",steps:80}
        },
        grow: {stepMode:"linear",stepDirection:"up",steps:80},
        grid: {
            hoverable: true,
            clickable: true,
            tickColor: "#d5d5d5",
            borderWidth: 1,
            color: '#d5d5d5'
        },
        colors: ["#1ab394", "#1C84C6"],
        xaxis: {
        },
        yaxis: {
            ticks: 4
        },
        tooltip: false
    };

    $scope.flotData = [data1, data2];
    $scope.flotOptions = options;
}

function SeverityCtrl($scope, Alert, Graph, $compile, $stateParams, $interval, $rootScope, $timeout) {

    $scope.severity = $scope.map_severity($stateParams.severity)

    $scope.currentGraph = 0;
    var graphDataA;
    var graphDataB;

    $scope.showSeverityGraph = function(index){
        graphDataA = [];
        graphDataB = [];
        $scope.currentGraph = index;
        $timeout( function() {
            Alert.get({}, function(response){

                $scope.selectedAlerts = $scope.resolveAlerts(response.data)[$stateParams.severity];

                Graph.get({keyId: $scope.selectedAlerts[index][0].split(';')[0], timeId: $scope.selectedAlerts[index][0].split(';')[1]}, function(response){
                    angular.forEach(response.data[resolveKeyJson($scope.selectedAlerts[index][0].split(';')[0], $scope.selectedAlerts[index][0].split(';')[1])], function(data) {
                        graphDataA.push([data[2], data[0]]);
                        graphDataB.push([data[2], data[1]]);
                    });
                })
            })
        }, 1000);
    }

    $scope.showSeverityGraph($scope.currentGraph);

    function resolveKeyJson(key, period){
        return key + ';' + period;
    }

    $scope.multiData = [
        {
            data: graphDataA,
            label: "Metric 1"
        },
        {
            data: graphDataB,
            label: "Metric 2",
        }
    ];

    $scope.multiOptions = {
        xaxes: [
            {
                mode: 'time'
            }
        ],
        yaxes: [],
        legend: {
            position: 'ne'
        },
        colors: ["#6666EC", "#1ab394"],
        grid: {
            color: "#999999",
            hoverable: true,
            clickable: true,
            tickColor: "#D4D4D4",
            borderWidth: 0

        },
        tooltip: true,
        tooltipOpts: {
            content: "%s - %y",
            xDateFormat: "%y-%0m-%0d",
            onHover: function (flotItem, $tooltipEl) {
            }
        }
    };
}


function translateCtrl($translate, $scope) {
    $scope.changeLanguage = function (langKey) {
        $translate.use(langKey);
    };
}

angular
    .module('mule')
    .controller('AppCtrl', AppCtrl)
    .controller('HomeCtrl', HomeCtrl)
    .controller('GraphCtrl', GraphCtrl)
    .controller('SeverityCtrl', SeverityCtrl)
    .controller('DashboardCtrl', DashboardCtrl)
    .controller('translateCtrl', translateCtrl);
