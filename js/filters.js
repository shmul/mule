function keylength(){
  return function(input){
    if(angular.isObject(input)){
      return Object.keys(input).length;
    }
  }
}

function singleDecimal(){
  return function(input) {
    if (isNaN(input)) return input;
      return Math.round(input * 10) / 10;
  };
}


function custom(){
  return function(input, search) {
    if (!input) return input;
    if (!search) return input;
    var expected = ('' + search).toLowerCase();
    var result = {};
    angular.forEach(input, function(value, key) {
      var actual = ('' + key).toLowerCase();
      if (actual.indexOf(expected) !== -1) {
        result[key] = value;
      }
    });
    return result;
  }
}

angular
    .module('mule')
    .filter('keylength', keylength)
    .filter('singleDecimal', singleDecimal)
    .filter('custom', custom)


