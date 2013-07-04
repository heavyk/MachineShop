var Fs, Path, Url, spawn, _, mkdirp, debug, nw_version, v8_version, v8_mode, out$ = typeof exports != 'undefined' && exports || this;
Fs = require('fs');
Path = require('path');
Url = require('url');
spawn = require('child_process').spawn;
_ = require('lodash');
mkdirp = require('mkdirp');
debug = require('debug')('utils');
out$.nw_version = nw_version = process.versions['node-webkit'];
out$.v8_version = v8_version = (nw_version ? 'nw' : 'node') + '_' + process.platform + '_' + process.arch + '_' + process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/)[0];
out$.v8_mode = v8_mode = 'Release';
if (nw_version || true) {
  global.Fiber = function(cb){
    return {
      run: function(){
        return cb();
      }
    };
  };
  global.Future = function(){
    return {
      wait: function(){
        throw new Error("Future.wait not implemented!");
      },
      'return': function(){
        throw new Error("Future.return not implemented!");
      }
    };
  };
} else {
  global.Fiber = require('fibers');
  global.Future = require('fibers/future');
}
Fiber(function(){
  var scan, parse, isDirectory, unquote, isQuoted, stripEscapeCodes, mkdir, exists, stat, readdir, readFile, writeFile, exec, recursive_hardlink, Config;
  scan = function(str){
    var re, toks, tok, m, braceExpand;
    re = /(?:(\S*"[^"]+")|(\S*'[^']+')|(\S+))/g;
    toks = [];
    tok = void 8;
    m = void 8;
    braceExpand = require('minimatch').braceExpand;
    while (m = re.exec(str)) {
      tok = m[0];
      tok = braceExpand(tok, {
        nonegate: true
      });
      toks = toks.concat(tok);
    }
    return toks;
  };
  out$.parse = parse = function(str){
    var toks, cmds, cmd, i$, len$, i, tok, part;
    toks = scan(str);
    cmds = [];
    cmd = {
      env: {},
      argv: []
    };
    for (i$ = 0, len$ = toks.length; i$ < len$; ++i$) {
      i = i$;
      tok = toks[i$];
      if ('|' === tok) {
        continue;
      }
      if (tok.indexOf('=') > 0) {
        part = tok.split('=');
        cmd.env[part.shift()] = unquote(part.join('='));
      } else {
        cmd.name = tok;
        while (toks[i + 1] && toks[i + 1] !== '|') {
          cmd.argv.push(toks[++i]);
        }
        cmds.push(cmd);
        cmd = {
          env: {},
          argv: []
        };
      }
    }
    return cmds;
  };
  out$.isDirectory = isDirectory = function(path){
    var s, err;
    debug("isDirectory %s", path);
    try {
      s = stat(path);
      return s.isDirectory();
    } catch (e$) {
      err = e$;
      return false;
    }
  };
  out$.unquote = unquote = function(str){
    return str.replace(/^"|"$/g, '').replace(/^'|'$/g, '').replace(/\n/g, '\n');
  };
  out$.isQuoted = isQuoted = function(str){
    return '"' === str[0] || '\'' === str[0];
  };
  out$.stripEscapeCodes = stripEscapeCodes = function(str){
    return str.replace(/\033\[[^m]*m/g, '');
  };
  out$.mkdir = mkdir = function(path, cb){
    var future;
    debug("mkdir %s -> %s", path, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    if (typeof cb === 'function') {
      return mkdirp(path, cb);
    } else if (Fiber.current) {
      future = new Future;
      mkdirp(path, function(err, d){
        return future['return'](err) || d;
      });
      return future.wait();
    } else {
      return mkdirp.sync(path);
    }
  };
  out$.exists = exists = function(path, cb){
    var future, v;
    debug("exists %s -> %s", path, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    if (typeof cb === 'function') {
      return Fs.exists(path, cb);
    } else if (Fiber.current) {
      future = new Future;
      Fs.exists(path, function(exists){
        return future['return'](exists);
      });
      v = future.wait();
      return v;
    } else {
      return Fs.existsSync(path);
    }
  };
  out$.stat = stat = function(path, cb){
    var future;
    debug("stat %s -> %s", path, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    if (typeof cb === 'function') {
      return Fs.stat(path, cb);
    } else if (Fiber.current) {
      future = new Future;
      Fs.stat(path, function(err, st){
        return future['return'](err) || st;
      });
      return future.wait();
    } else {
      return Fs.statSync(path);
    }
  };
  out$.readdir = readdir = function(path, cb){
    var future, files, err;
    debug("readdir(%s) %s", path, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    if (typeof cb === 'function') {
      return Fs.readdir(path, cb);
    } else if (Fiber.current) {
      future = new Future;
      Fs.readdir(path, function(err, files){
        if (!err) {
          _.each(files, function(file, i){
            var f;
            f = {};
            Object.defineProperty(f, 'st', {
              get: function(){
                return stat(file);
              }
            });
            return Object.defineProperty(f, 'toString', {
              get: function(){
                return file;
              }
            });
          });
        }
        return future['return'](err) || files;
      });
      return future.wait();
    } else {
      try {
        files = Fs.readdirSync(path);
        _.each(files, function(file, i){
          var f;
          f = {};
          Object.defineProperty(f, 'st', {
            get: function(){
              return stat(file);
            }
          });
          return Object.defineProperty(f, 'toString', {
            get: function(){
              return file;
            }
          });
        });
      } catch (e$) {
        err = e$;
        throw err;
      }
      return files;
    }
  };
  out$.readFile = readFile = function(path, enc, cb){
    var future;
    debug("readFile %s -> %s", path, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    if (typeof cb === 'function') {
      return Fs.readFile(path, enc, cb);
    } else if (Fiber.current) {
      future = new Future;
      Fs.readFile(path, enc, function(err, st){
        return future['return'](err) || st;
      });
      return future.wait();
    } else {
      return Fs.readFileSync(path, enc);
    }
  };
  out$.writeFile = writeFile = function(path, data, cb){
    var future;
    debug("writeFile %s -> %s", path, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    if (typeof cb === 'function') {
      return Fs.writeFile(path, data, cb);
    } else if (Fiber.current) {
      future = new Future;
      Fs.writeFile(path, data, function(err, st){
        return future['return'](err) || st;
      });
      return future.wait();
    } else {
      return Fs.writeFileSync(path, data);
    }
  };
  out$.exec = exec = function(cmd, opts, cb){
    var cmds, p;
    if (typeof opts === 'function') {
      cb = opts;
      opts = {
        stdio: 'inherit'
      };
    }
    if (!opts.stdio) {
      opts.stdio = 'inherit';
    }
    if (!opts.env) {
      opts.env = process.env;
    }
    cmds = cmd.split(' ');
    p = spawn(cmds[0], cmds.slice(1), opts);
    return p.on('close', function(code){
      if (code) {
        return cb(new Error("exit code: " + code));
      } else {
        return cb(code);
      }
    });
  };
  out$.recursive_hardlink = recursive_hardlink = function(path, into, cb){
    var rh, future, files, err;
    debug("recursive_hardlink %s -> %s", path, into, typeof cb === 'function'
      ? 'callback'
      : Fiber.current ? 'fiber' : 'sync');
    rh = function(done){
      return Fs.readdir(path, function(err, files){
        if (err) {
          return cb(err);
        }
      });
    };
    if (typeof cb === 'function') {
      return Fs.readdir(path, cb);
    } else if (Fiber.current) {
      future = new Future;
      Fs.readdir(path, function(err, files){
        if (!err) {
          _.each(files, function(file, i){
            var f;
            f = {};
            Object.defineProperty(f, 'st', {
              get: function(){
                return stat(file);
              }
            });
            return Object.defineProperty(f, 'toString', {
              get: function(){
                return file;
              }
            });
          });
        }
        return future['return'](err) || files;
      });
      return future.wait();
    } else {
      try {
        files = Fs.readdirSync(path);
        _.each(files, function(file, i){
          var f;
          f = {};
          Object.defineProperty(f, 'st', {
            get: function(){
              return stat(file);
            }
          });
          return Object.defineProperty(f, 'toString', {
            get: function(){
              return file;
            }
          });
        });
      } catch (e$) {
        err = e$;
        throw err;
      }
      return files;
    }
  };
  out$.Config = Config = function(path, initial_obj, save_fn){
    var debug, EventEmitter, Proxy, _config, ex, ee, save, make_reflective, config;
    debug = require('debug')('config:' + path);
    EventEmitter = require('eventemitter2').EventEmitter2;
    if (typeof WeakMap !== 'function') {
      global.WeakMap = require('es6-collections').WeakMap;
    }
    if (typeof Proxy !== 'object' && !process.versions['node-webkit']) {
      global.Proxy = Proxy = require('node-proxy');
    }
    if (typeof Reflect !== 'function') {
      require('harmony-reflect');
    }
    try {
      _config = Fs.readFileSync(path, 'utf-8');
      _config = JSON.parse(_config);
    } catch (e$) {
      ex = e$;
      _config = {};
      mkdir(Path.dirname(path));
    }
    if (typeof initial_obj === 'function') {
      save_fn = initial_obj;
    } else if (typeof initial_obj === 'object') {
      _config = import$(initial_obj, _config);
    }
    ee = new EventEmitter;
    save = _.throttle(function(){
      var obj;
      if (Config._saving[path]) {
        debug(path + " already being saved... waiting 10ms before trying again");
        return;
      }
      Config._saving[path] = true;
      obj = config;
      debug("saving...", path);
      /*
      future = new Future
      setTimeout ->
      	future.return!
      , 50ms
      future.wait!
      #*/
      debug("writing...", path, obj);
      return writeFile(path, JSON.stringify(obj, null, '\t'), function(err){
        if (typeof save_fn === 'function') {
          save_fn(obj);
        }
        Config._saving[path] = false;
        return ee.emit('save', obj);
      });
    }, 10, {
      leading: true,
      trailing: true
    });
    make_reflective = function(o, oon, scoped_ee){
      var oo, reflective, k, v;
      oo = Array.isArray(o)
        ? []
        : {};
      if (!scoped_ee) {
        scoped_ee = new EventEmitter({
          wildcard: true
        });
      }
      reflective = Reflect.Proxy({}, {
        enumerable: true,
        enumerate: function(obj){
          return Object.keys(oo);
        },
        hasOwn: function(obj, key){
          return typeof oo[key] !== 'undefined';
        },
        keys: function(){
          return Object.keys(oo);
        },
        get: function(obj, name){
          var v;
          if (name === 'toJSON') {
            return function(){
              return oo;
            };
          } else if (name === 'inspect') {
            return function(){
              return require('util').inspect(oo);
            };
          } else if (typeof (v = oo[name]) !== 'undefined') {
            return v;
          } else {
            return scoped_ee[name];
          }
        },
        set: function(obj, name, val){
          var prop;
          debug("(set) " + (oon ? oon + '.' + name : name) + " -> %s", val);
          if ((typeof val === 'object' && !_.isEqual(oo[name], val)) || oo[name] !== val) {
            prop = oon ? oon + "." + name : name;
            if (name === '_all') {
              scoped_ee[name] = val;
            } else {
              debug("set: %s -> %s", prop, val);
              if (typeof val === 'object') {
                val = make_reflective(val, prop);
              }
              oo[name] = val;
              save();
            }
          }
          return val;
        }
      });
      for (k in o) {
        v = o[k];
        reflective[k] = v;
      }
      return reflective;
    };
    Config._saving[path] = true;
    Config._[path] = config = make_reflective(_config, '', ee);
    if (initial_obj) {
      _.each(initial_obj, function(v, k){
        if (k !== '_events') {
          if (typeof v === 'object') {
            return config[k] = make_reflective(v, k, save);
          } else {
            return Config._[path][k] = v;
          }
        }
      });
    }
    /*
    Object.defineProperty config, "_events", {
    	get: -> ee
    }*/
    debug("created Config object");
    Config._saving[path] = false;
    return config;
  };
  Config._saving = {};
  return Config._ = {};
}).run();
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}