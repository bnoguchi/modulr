var require = (function() {
  var _isArray = Array.isArray || function(obj) {
        return !!(obj && obj.concat && obj.unshift && !obj.callee);
      }
    , _keys = Object.keys || function(obj) {
        if (_isArray(obj)) return _.range(0, obj.length);
        var keys = [];
        for (var key in obj) if (Object.prototype.hasOwnProperty.call(obj, key)) keys[keys.length] = key;
        return keys;
      }
    , _dependencyGraph = {}
    , _factories = {} // Maps "ids" to factories that load its logic into a module.exports
    , _modules = {} // Maps "keys" to module objects of form {id: ..., exports: {...}}
    , _currDir
    , _contexts = [_currDir = './']
    , PREFIX = '__module__'; // Prefix identifiers to avoid issues in IE.
      
  /**
   * While context: ./
   * ----REQUIRE----             ----FACTORY NAME----
   * require('./index') ->       ./index
   * require('../lib/class')     ./../lib/class
   * require('lingo')            PATH/lingo
   *
   * While context: PATH/lingo/
   * require('./lib')            PATH/lingo/lib
   * require('../dir/index')     PATH/lingo/../dir/index
   * require('utils')            PATH/utils
   *
   * While context: PATH/lingo/../dir/
   * require('./lib')            PATH/lingo/../dir/lib
   * require('../lib')           PATH/lingo/../lib
   * require('../../lib')        PATH/lingo/../../lib  [PATH, lingo, .., dir, .., .., lib]
   *  
   */
  function require (identifier) {
    var id = resolveIdentifier(identifier)
      , key = PREFIX + id
      , mod = _modules[key] || (_modules[key] = loadModule(identifier, id, key));
    return mod.exports;
  }

  function loadModule (identifier, id, key) {
    var fn = _factories[key]
      , mod = { id: id, exports: {} }
      , expts = mod.exports;
    _contexts.push(_currDir = id.substring(0, id.lastIndexOf('/') + 1))
    try {
      if (!fn) { throw 'Can\'t find module "' + identifier + '" keyed as "' + id + '".'; }
      if (typeof fn === 'string') {
        fn = new Function('require', 'exports', 'module', fn);
      }
      fn(require, expts, mod);
      if (_keys(expts).length) mod.exports = expts;
      _contexts.pop();
      _currDir = _contexts[_contexts.length-1];
    } catch(e) {
      _contexts.pop();
      _currDir = _contexts[_contexts.length-1];
      // We'd use a finally statement here if it wasn't for IE.
      throw e;
    }
    return mod;
  }
  
  function resolveIdentifier (identifier) {
    if (identifier.charAt(0) !== '.') { // This module exists relative to PATH/
      var dir = ['PATH', identifier, ''].join('/');
      return _factories[PREFIX + dir + 'index'] 
        ? (dir + 'index')
        : dir.substring(0, dir.length-1);
    }

    var parts, part, path, dir;
    parts = _currDir.split('/').concat(identifier.split('/'));
    path = [];
    for (var i = 0, l = parts.length; i < l; i++) {
      part = parts[i];
      if (part === '') continue;
      if (part === '.') {
        if (path.length === 0 && parts[0] === '.') {
          path.push(part);
        }
      } else if (part === '..') {
        if (path[path.length-1].charAt(0) === '.' ||
            parts[0] === 'PATH' && path.length === 2) {
          path.push(part);
        } else {
          path.pop();
        }
      } else {
        path.push(part);
      }
    }
    return path.join('/');
  }
  
  function define (id2module) {
    for (var id in id2module) {
      _factories[PREFIX + id] = id2module[id];
    }
  }
  
  function ensure(factory) {
    factory();
  }
  
  require.define = define;
  require.ensure = ensure;
  require.main = {};

  return require; 
})()
, module = require.main;
