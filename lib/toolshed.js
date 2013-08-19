var Fs, Path, Url, spawn, _, mkdirp, debug, nw_version, v8_version, v8_mode, scan, parse, isDirectory, unquote, isQuoted, stripEscapeCodes, mkdir, exists, stat, readdir, readFile, writeFile, exec, recursive_hardlink, Config, stringify, out$ = typeof exports != 'undefined' && exports || this;
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
out$.Config = Config = function(path, initial_obj, opts, save_fn){
  var debug, EventEmitter, WeakMap, Proxy, Reflect, ee, config, iid, save, make_reflective;
  debug = require('debug')('config:' + path);
  EventEmitter = require('events').EventEmitter;
  WeakMap = global.WeakMap;
  Proxy = global.Proxy;
  Reflect = global.Reflect;
  if (typeof WeakMap === 'undefined') {
    WeakMap = global.WeakMap = require('es6-collections').WeakMap;
  }
  if (typeof Proxy === 'undefined' && !process.versions['node-webkit']) {
    console.log("!!!!!!! installing node-proxy cheat...");
    global.Proxy = Proxy = require('node-proxy');
  }
  if (typeof Reflect === 'undefined') {
    require('harmony-reflect');
    Reflect = global.Reflect;
  }
  ee = new EventEmitter;
  if (typeof initial_obj === 'function') {
    opts = {
      watch: true
    };
    save_fn = initial_obj;
  } else if (typeof opts === 'function') {
    save_fn = opts;
    opts({
      watch: true
    });
  }
  iid = false;
  save = function(){
    Config._saving[path]++;
    if (iid === false) {
      return iid = setInterval(function(){
        var obj;
        obj = config;
        debug("writing...", path);
        Config._saving[path] = 0;
        return writeFile(path, stringify(obj), function(err){
          if (typeof save_fn === 'function') {
            save_fn(obj);
          }
          ee.emit('save', obj, path);
          if (!Config._saving[path]) {
            clearInterval(iid);
            return iid = false;
          }
        });
      }, 500);
    }
  };
  make_reflective = function(o, oon, scoped_ee){
    var oo, reflective, k, v;
    oo = Array.isArray(o)
      ? []
      : {};
    if (!scoped_ee) {
      scoped_ee = new EventEmitter;
    }
    reflective = Reflect.Proxy(oo, {
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
        var v, args, body;
        if (name === 'toJSON') {
          return function(){
            return oo;
          };
        } else if (name === 'inspect') {
          return function(){
            return require('util').inspect(oo);
          };
        } else if ((v = oo[name]) === null && oo[name + '.js']) {
          v = oo[name + '.js'];
          args = v.match(/function \((.*)\)/);
          body = v.substring(1 + v.indexOf('{'), v.lastIndexOf('}'));
          return oo[name] = Function(args[1], body);
        } else if (typeof v !== 'undefined') {
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
            if (typeof val === 'object' && v !== null) {
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
  Config._[path] = config = make_reflective({}, '', ee);
  if (initial_obj) {
    _.each(initial_obj, function(v, k){
      if (k !== '_events') {
        if (typeof v === 'object' && v !== null) {
          return config[k] = make_reflective(v, k, save);
        } else {
          return Config._[path][k] = v;
        }
      }
    });
  }
  Fs.readFile(path, 'utf-8', function(err, data){
    var _config, ex;
    try {
      _config = JSON.parse(data);
      _.each(_config, function(v, k){
        if (typeof v === 'object' && v !== null) {
          return config[k] = make_reflective(v, k, save);
        } else {
          return Config._[path][k] = v;
        }
      });
      config.emit('ready', null, path);
    } catch (e$) {
      ex = e$;
      config.emit('ready', ex, path);
    }
    debug("created Config object");
    return Config._saving[path] = false;
  });
  return config;
};
Config._saving = {};
Config._ = {};
out$.stringify = stringify = function(obj, indent){
  var out, iindent, k, i$, len$, key, o;
  indent == null && (indent = 1);
  out = [];
  iindent = repeatString$('\t', indent);
  k = Object.keys(obj).sort();
  for (i$ = 0, len$ = k.length; i$ < len$; ++i$) {
    key = k[i$];
    if ((o = obj[key]) === null) {
      out.push('"' + key + '": null');
    } else {
      switch (typeof o) {
      case 'function':
        out.push('"' + key + '": null');
        o = o.toString();
        key += '.js';
        if (typeof obj[key] === 'undefined') {
          out.push('"' + key + '": "' + o.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"');
        }
        break;
      case 'string':
        out.push('"' + key + '": "' + o.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n') + '"');
        break;
      case 'number':
      case 'boolean':
        out.push('"' + key + '": ' + o);
        break;
      case 'object':
        out.push('"' + key + '": ' + stringify(o, indent + 1));
      }
    }
  }
  return ("{\n" + iindent) + out.join(",\n" + iindent) + ("\n" + repeatString$('\t', indent - 1) + "}");
};
function repeatString$(str, n){
  for (var r = ''; n > 0; (n >>= 1) && (str += str)) if (n & 1) r += str;
  return r;
}