angular.module('mule')

.factory('$localstorage', ['$window', function($window) {
  return {
    set: function(key, value) {
      $window.localStorage[key] = value;
    },
    get: function(key, defaultValue) {
      return $window.localStorage[key] || defaultValue;
    },
    setObject: function(key, value) {
      $window.localStorage[key] = JSON.stringify(value);
    },
    getObject: function(key) {
      return JSON.parse($window.localStorage[key] || '{}');
    }
  }
}])


.factory('Keys', function ($rootScope, $resource , $localstorage) {
  return $resource($rootScope.server + '/:resource/:keyId', { resource:'key', level: 1 });
})

.factory('Graph', function ($rootScope, $resource , $localstorage) {
  return $resource($rootScope.server + '/:resource/:keyId' + ';' + ':timeId', { resource:'graph', filter: 'now' });
})

.factory('Alert', function ($rootScope, $resource , $localstorage) {
  return $resource($rootScope.server + '/alert', {});
})
