// modulr (c) 2010 codespeaks sàrl
// Freely distributable under the terms of the MIT license.
// For details, see:
//   http://github.com/codespeaks/modulr/blob/master/LICENSE

var modulr = (function(global) {
  var _modules = {},
      _moduleObjects = {},
      _exports = {},
      _oldDir = '',
      _currentDir = '',
      PREFIX = '__module__', // Prefix identifiers to avoid issues in IE.
      RELATIVE_IDENTIFIER_PATTERN = /^\.\.?\//;
      
  var _forEach = (function() {
    var hasOwnProp = Object.prototype.hasOwnProperty,
        DONT_ENUM_PROPERTIES = [
          'constructor',
          'toString',
          'toLocaleString',
          'valueOf',
          'hasOwnProperty',
          'isPrototypeOf',
          'propertyIsEnumerable'
        ],
        LENGTH = DONT_ENUM_PROPERTIES.length,
        DONT_ENUM_BUG = true;
    
    function _forEach(obj, callback) {
      for(var prop in obj) {
        if (hasOwnProp.call(obj, prop)) {
          callback(prop, obj[prop]);
        }
      }
    }
    
    for(var prop in { toString: true }) {
      DONT_ENUM_BUG = false
    }
    
    if (DONT_ENUM_BUG) {
      return function(obj, callback) {
         _forEach(obj, callback);
         for (var i = 0; i < LENGTH; i++) {
           var prop = DONT_ENUM_PROPERTIES[i];
           if (hasOwnProp.call(obj, prop)) {
             callback(prop, obj[prop]);
           }
         }
       }
    }
    
    return _forEach;
  })();
  
  function log(str) {
    if (global.console && console.log) { console.log(str); }
  }
  
  function require(identifier) {
    var fn, modObj,
        id = resolveIdentifier(identifier),
        key = PREFIX + id,
        expts = _exports[key];
    
    log('Required module "' + identifier + '".');
    
    if (!expts) {
      _exports[key] = expts = {};
      _moduleObjects[key] = modObj = { id: id };
      
      if (!require.main) { require.main = modObj; }
      
      fn = _modules[key];
      _oldDir = _currentDir;
      _currentDir = id.slice(0, id.lastIndexOf('/'));
      
      try {
        if (!fn) { throw 'Can\'t find module "' + identifier + '".'; }
        if (typeof fn === 'string') {
          fn = new Function('require', 'exports', 'module', fn);
        }
        fn(require, expts, modObj);
        _currentDir = _oldDir;
      } catch(e) {
        _currentDir = _oldDir;
        // We'd use a finally statement here if it wasn't for IE.
        throw e;
      }
    }
    return expts;
  }
  
  function resolveIdentifier(identifier) {
    var parts, part, path;
    
    if (!RELATIVE_IDENTIFIER_PATTERN.test(identifier)) {
      return identifier;
    }
    
    parts = (_currentDir + '/' + identifier).split('/');
    path = [];
    for (var i = 0, length = parts.length; i < length; i++) {
      part = parts[i];
      switch (part) {
        case '':
        case '.':
          continue;
        case '..':
          path.pop();
          break;
        default:
          path.push(part);
      }
    }
    return path.join('/');
  }
  
  function cache(id, fn) {
    var key = PREFIX + id;
    
    log('Cached module "' + id + '".');
    _modules[key] = fn;
  }
  
  function define(moduleDescriptors) {
    _forEach(moduleDescriptors, function(k, v) {
      _modules[PREFIX + k] = v; 
    });
  }
  
  function ensure(identifiers, onAvailable, onMissing) {
    for (var i = 0, length = identifiers.length; i < length; i++) {
      var identifier = identifiers[i];
      if (!_modules[PREFIX + identifier]) {
        var error = new Error('Can\'t find module "' + identifier + '".')
        if (typeof onMissing === 'function') {
          onMissing(error);
          return;
        }
        throw error;
      }
    }
    onAvailable();
  }
  
  require.define = define;
  require.ensure = ensure;
  
  return {
    require: require,
    cache: cache
  };
})(this);
