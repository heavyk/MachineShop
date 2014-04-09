var Fs, Path, Url, assert, spawn, mkdirp, Rimraf, printf, EventEmitter, _, nw_version, v8_version, HOME_DIR, v8_mode, Debug, debug, Fiber, Future, scan, parse, rimraf, isDirectory, unquote, isQuoted, stripEscapeCodes, mkdir, exists, stat, readdir, readFile, writeFile, exec, searchDownwardFor, recursive_hardlink, Scope, Config, regex_slash, regex_quote, regex_newline, regex_tab, regex_tabspace, regex_space, regex_newspace, res$, i$, i, _iindent, clean_str, stringify, da_funk_scopes, da_funk_callthrough, empty_scope, da_funk, objectify, merge, extend, embody, debug_fn, out$ = typeof exports != 'undefined' && exports || this;
Fs = require('fs');
Path = require('path');
Url = require('url');
assert = require('assert');
spawn = require('child_process').spawn;
mkdirp = require('mkdirp');
Rimraf = require('rimraf');
printf = require('printf');
out$.EventEmitter = EventEmitter = require('eventemitter3').EventEmitter;
out$._ = _ = require('lodash');
out$.nw_version = nw_version = process.versions ? process.versions['node-webkit'] : void 8;
out$.v8_version = v8_version = (nw_version ? 'nw' : 'node') + '_' + process.platform + '_' + process.arch + '_' + (process.versions
  ? process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/)[0] + '-' + process.versions.modules
  : typeof window === 'object' ? 'browser' : 'unknown');
out$.HOME_DIR = HOME_DIR = process.platform === 'win32'
  ? process.env.USERPROFILE
  : process.env.HOME;
out$.v8_mode = v8_mode = 'Release';
out$.Debug = Debug = function(namespace){
  var path, debug, start;
  if (!(path = Debug.namespaces[namespace])) {
    path = process.cwd();
  }
  if (HOME_DIR) {
    debug = function(){
      var msg;
      msg = printf.apply(this, arguments);
      Fs.appendFileSync(path, "[DEBUG] " + namespace + ": " + msg + "\n");
    };
    debug.warn = function(){
      var msg;
      msg = printf.apply(this, arguments);
      Fs.appendFileSync(path, "[WARN] " + namespace + ": " + msg + "\n");
    };
    debug.info = function(){
      var msg;
      msg = printf.apply(this, arguments);
      Fs.appendFileSync(path, "[INFO] " + namespace + ": " + msg + "\n");
    };
    debug.todo = function(){
      var msg;
      msg = printf.apply(this, arguments);
      Fs.appendFileSync(path, "[TODO] " + namespace + ": " + msg + "\n");
    };
    debug.error = function(){
      var msg;
      msg = printf.apply(this, arguments);
      Fs.appendFileSync(path, "[ERROR] " + namespace + ": " + msg + "\n");
    };
    debug.log = function(){
      var msg;
      msg = printf.apply(this, arguments);
      Fs.appendFileSync(path, "[LOG] " + namespace + ": " + msg + "\n");
    };
    start = function(){
      path = Path.join(HOME_DIR, '.ToolShed', "debug.log");
      return mkdirp(Path.dirname(path), function(err){
        Fs.writeFileSync(path, "");
        return debug("starting...");
      });
    };
    debug.namespace = [
      ~function(){
        return namespace;
      }, ~function(v){
        start();
        return namespace = v;
      }
    ];
    debug.assert = assert;
    start();
  } else {
    debug = function(){
      var msg;
      msg = printf.apply(this, arguments);
      console.debug(namespace + ": " + msg);
    };
    debug.todo = function(){
      var msg;
      msg = printf.apply(this, arguments);
      console.info(namespace + ": [TODO] " + msg);
    };
    debug.warn = function(){
      var msg;
      msg = printf.apply(this, arguments);
      console.warn(namespace + ": " + msg);
    };
    debug.info = function(){
      var msg;
      msg = printf.apply(this, arguments);
      console.info(namespace + ": " + msg);
    };
    debug.error = function(){
      var msg;
      msg = printf.apply(this, arguments);
      console.error(namespace + ": " + msg);
    };
    debug.log = function(){
      var msg;
      msg = printf.apply(this, arguments);
      console.log(namespace + ": " + msg);
    };
    debug.assert = assert;
    debug.namespace = [
      ~function(){
        return namespace;
      }, ~function(v){
        return namespace = v;
      }
    ];
  }
  return debug;
};
Debug.namespaces = {};
Debug.colors = true;
debug = Debug('ToolShed');
Fiber = function(){};
out$.Future = Future = function(){};
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
out$.rimraf = rimraf = function(dir, cb){
  if (typeof cb === 'function') {
    return Rimraf(dir, cb);
  } else {
    return Rimraf(dir, function(){});
  }
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
  if (typeof enc === 'function') {
    cb = enc;
    enc = 'utf-8';
  }
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
out$.searchDownwardFor = searchDownwardFor = function(file, dir, cb){
  var test_dir;
  if (typeof dir === 'function') {
    cb = dir;
    dir = process.cwd();
  }
  test_dir = function(dir){
    var path;
    path = Path.join(dir, file);
    debug("testing %s", path);
    return Fs.stat(path, function(err, st){
      if (err) {
        if (err.code === 'ENOENT') {
          dir = Path.resolve(dir, '..');
          if (dir === Path.sep) {
            return cb(err);
          } else {
            return test_dir(dir);
          }
        }
      } else if (st.isFile()) {
        return cb(null, path);
      } else {
        return console.log("....", st);
      }
    });
  };
  return test_dir(dir);
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
out$.Scope = Scope = function(scope_name, initial_obj, save_fn){
  var debug, WeakMap, Proxy, Reflect, ee, scope, written_json_str, iid, save, make_reflective;
  debug = Debug('scope:' + scope_name);
  WeakMap = global.WeakMap;
  Proxy = global.Proxy;
  Reflect = global.Reflect;
  if (typeof WeakMap === 'undefined') {
    WeakMap = global.WeakMap = require('es6-collections').WeakMap;
  }
  if (typeof Proxy === 'undefined' && !process.versions['node-webkit']) {
    global.Proxy = Proxy = require('node-proxy');
  }
  if (typeof Reflect === 'undefined') {
    require('harmony-reflect');
    Reflect = global.Reflect;
  }
  ee = new EventEmitter;
  if (typeof initial_obj === 'function') {
    save_fn = initial_obj;
    initial_obj = void 8;
  }
  iid = false;
  save = function(){
    var clear_interval;
    clear_interval = function(){
      if (!Scope._saving[scope_name]) {
        clearInterval(iid);
        return iid = false;
      }
    };
    Scope._saving[scope_name]++;
    if (iid === false) {
      return iid = setInterval(function(){
        var obj, json_str;
        obj = scope;
        json_str = JSON.stringify(obj);
        if (json_str !== written_json_str) {
          written_json_str = json_str;
          if (typeof save_fn === 'function') {
            save_fn(obj);
          }
          ee.emit('save', obj, scope_name, json_str);
          clear_interval();
        } else {
          clear_interval();
        }
        return Scope._saving[scope_name] = 0;
      }, 500);
    }
  };
  make_reflective = function(o, oon){
    var oo, reflective, k, v;
    oo = Array.isArray(o)
      ? []
      : {};
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
        } else if ((v = oo[name]) === 8 && oo[name + '.js']) {
          v = oo[name + '.js'];
          args = v.match(/function \((.*)\)/);
          body = v.substring(1 + v.indexOf('{'), v.lastIndexOf('}'));
          return oo[name] = Function(args[1], body);
        } else if (typeof v !== 'undefined') {
          return v;
        } else if (oon.length === 0) {
          return ee[name];
        }
      },
      set: function(obj, name, val){
        var prev_val, prop;
        prev_val = oo[name];
        if ((typeof val === 'object' && !_.isEqual(oo[name], val)) || oo[name] !== val) {
          prop = oon ? oon + "." + name : name;
          if (typeof val === 'object' && v !== null) {
            val = make_reflective(val, prop);
          }
          if (Array.isArray(val)) {
            debug("TODO: add the addedAt / removedAt events (see code)");
            /*
            new_objs = []
            existing_objs = []
            removed = []
            for d in docs => new_objs.push d._id.toHexString!
            for d in _docs => existing_objs.push d._id.toHexString!
            
            for id, i in existing_objs
            	if ~(ii = new_objs.indexOf id)
            		if ii is i and _dd = _docs[i] and d = docs[i]
            			dd = d.toObject!
            			_dd = _dd.toObject!
            			_.each dd, (v, k) ~>
            				# for now, I think the safest comparison we can do is simply converting both sides to a string:
            				if k isnt \_id and _dd[k]+'' isnt v+''
            					_docs.splice i, 1, d
            					ee.emit \changedAt, d, _docs[i], i
            	else
            		console.log id, "NOT found in new objs", i
            		removed.push id
            
            for id in removed
            	if ~(i = existing_objs.indexOf id)
            		ee.emit \removedAt, _docs[i], i
            		_docs.splice i, 1
            		existing_objs.splice i, 1
            	else
            		console.error "undefined error", id
            
            for id, i in new_objs
            	#id = d._id.toHexString!
            	if ~(ii = existing_objs.indexOf id)
            		if ii isnt i
            			existing_objs.splice ii, 1
            			ee.emit \movedTo _docs[ii], ii, i
            			existing_objs.splice i, 0, id
            	else
            		ee.emit \addedAt, docs[i], i
            		_docs.splice i, 0, docs[i]
            */
          }
          oo[name] = val;
          ee.emit('set', prop, val, prev_val);
          save();
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
  Scope._saving[scope_name] = true;
  Scope._[scope_name] = scope = make_reflective({}, '', ee);
  if (initial_obj) {
    debug("initial obj: %O", initial_obj);
    _.each(initial_obj, function(v, k){
      debug("k:%s, v:%O", k, v);
      if (typeof v === 'object' && v !== null) {
        return scope[k] = make_reflective(v, k, save);
      } else {
        return Scope._[scope_name][k] = v;
      }
    });
    Scope._saving[scope_name] = false;
  }
  return scope;
};
Scope._saving = {};
Scope._ = {};
out$.Config = Config = function(path, initial_obj, opts, save_fn){
  var debug, WeakMap, Proxy, Reflect, ee, config, written_json_str, iid, save, make_reflective;
  debug = Debug('config:' + path);
  WeakMap = global.WeakMap;
  Proxy = global.Proxy;
  Reflect = global.Reflect;
  if (typeof WeakMap === 'undefined') {
    global.WeakMap = WeakMap = require('es6-collections').WeakMap;
  }
  if (typeof Proxy === 'undefined' && !process.versions['node-webkit']) {
    debug("!!!!!!! installing node-proxy cheat...");
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
    opts = {
      watch: true
    };
  }
  if (typeof opts === 'undefined') {
    opts = {
      watch: true
    };
  }
  iid = false;
  save = function(){
    var clear_interval;
    clear_interval = function(){
      if (!Config._saving[path]) {
        clearInterval(iid);
        return iid = false;
      }
    };
    Config._saving[path]++;
    if (iid === false) {
      return iid = setInterval(function(){
        var obj, json_str;
        obj = config;
        json_str = opts.ugly
          ? JSON.stringify(obj)
          : stringify(obj, stringify.get_desired_order(path));
        if (json_str !== written_json_str) {
          console.log("writing...", path);
          debug("writing...", path);
          writeFile(path, json_str, function(err){
            var dirname;
            if (err) {
              if (err.code === 'ENOENT') {
                dirname = Path.dirname(path);
                console.log("WE HAVE NOENT.. creating", Path.dirname(path));
                mkdirp(dirname, function(err){
                  if (err) {
                    return ee.emit('error', err);
                  } else {
                    return save();
                  }
                });
              } else {
                ee.emit('error', err);
              }
            } else {
              written_json_str = json_str;
              if (typeof save_fn === 'function') {
                save_fn(obj);
              }
              ee.emit('save', obj, path, json_str);
            }
            return clear_interval();
          });
        } else {
          clear_interval();
        }
        return Config._saving[path] = 0;
      }, 500);
    }
  };
  make_reflective = function(o, oon){
    var oo, reflective, k, v;
    oo = Array.isArray(o)
      ? []
      : {};
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
        } else if (oon.length === 0) {
          return ee[name];
        }
      },
      set: function(obj, name, val){
        var prev_val, prop;
        prev_val = oo[name];
        if ((typeof val === 'object' && !_.isEqual(oo[name], val)) || oo[name] !== val) {
          prop = oon ? oon + "." + name : name;
          if (typeof val === 'object' && v !== null) {
            val = make_reflective(val, prop);
          }
          oo[name] = val;
          ee.emit('set', prop, val, prev_val);
          save();
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
  Fs.readFile(path, 'utf-8', function(err, data){
    var is_new, _config, e;
    is_new = false;
    if (err) {
      if (err.code === 'ENOENT') {
        config.emit('new');
        is_new = true;
      } else {
        config.emit('error', e);
      }
    } else {
      try {
        _config = JSON.parse(data);
        written_json_str = data;
        _.each(_config, function(v, k){
          return Config._[path][k] = v;
        });
      } catch (e$) {
        e = e$;
        config.emit('error', e);
      }
    }
    if (initial_obj) {
      merge(config, initial_obj);
    }
    if (data) {
      config.emit('ready', config, data);
    } else if (Config._saving[path]) {
      config.once('save', function(){
        debug("saved data ready");
        return config.emit('ready', config, data);
      });
    }
    return Config._saving[path] = false;
  });
  return config;
};
Config._saving = {};
Config._ = {};
regex_slash = new RegExp('\\\\', 'g');
regex_quote = new RegExp('"', 'g');
regex_newline = new RegExp('\n', 'g');
regex_tab = new RegExp('\t', 'g');
regex_tabspace = new RegExp('\t  ', 'g');
regex_space = new RegExp(' ', 'g');
res$ = [];
for (i$ = 0; i$ <= 10; ++i$) {
  i = i$;
  res$.push(new RegExp('\n' + repeatString$(' ', i), 'g'));
}
regex_newspace = res$;
regex_newline = regex_newspace[0];
res$ = [];
for (i$ = 0; i$ <= 4; ++i$) {
  i = i$;
  res$.push(repeatString$('\t', i));
}
_iindent = res$;
clean_str = function(str){
  "use strict";
  return (str + '').replace(regex_slash, '\\\\').replace(regex_quote, '\\"').replace(regex_newline, '\\n').replace(regex_tab, '\\t');
};
out$.stringify = stringify = function(obj, desired_order, indent){
  var out, iindent, k, doi, i, kk, i$, len$, key, o, fn, ii, j, jj, args, body, iii, len;
  desired_order == null && (desired_order = []);
  indent == null && (indent = 1);
  out = [];
  if (!(iindent = _iindent[indent])) {
    iindent = _iindent[indent] = repeatString$('\t', indent);
  }
  k = Object.keys(obj).sort();
  if ((doi = desired_order.length - 1) >= 0) {
    do {
      if (~(i = k.indexOf(desired_order[doi]))) {
        kk = k.splice(i, 1);
        k.unshift(kk[0]);
      }
    } while (--doi >= 0);
  }
  if (k.length) {
    for (i$ = 0, len$ = k.length; i$ < len$; ++i$) {
      key = k[i$];
      if ((o = obj[key]) === null) {
        out.push('"' + key + '": null');
      } else {
        switch (typeof o) {
        case 'function':
          out.push('"' + key + '": 8');
          o = o.toString();
          key += '.js';
          if (typeof obj[key] === 'undefined') {
            fn = o.toString();
            i = fn.indexOf('(');
            ii = fn.indexOf(')');
            j = fn.indexOf('{');
            jj = fn.lastIndexOf('}');
            args = fn.substring(++i, ii).replace(regex_space, '');
            body = fn.substring(++j, jj).trim();
            if (~(i = fn.indexOf('\n'))) {
              ii = i + 1;
              while (fn[ii] === ' ') {
                ii++;
              }
              if (!regex_newspace[iii = ii - i + 1 - 2]) {
                regex_newspace[iii] = new RegExp('\n' + repeatString$(' ', iii), 'g');
              }
              body = body.replace(regex_newspace[ii - i + 1 - 2], '\n\t');
              do {
                len = body.length;
                body = body.replace(regex_tabspace, '\t\t');
              } while (body.length !== len);
            }
            if (body.length) {
              body = '\\n\\t' + clean_str(body) + '\\n';
            }
            out.push('"' + key + '": "function(' + args + '){' + body + '}"');
          }
          break;
        case 'string':
          out.push('"' + key + '": "' + clean_str(o) + '"');
          break;
        case 'number':
        case 'boolean':
          out.push('"' + key + '": ' + o);
          break;
        case 'object':
          if (typeof o.length === 'number' || Array.isArray(o)) {
            if (o.length) {
              out.push('"' + key + ("\": [\n" + iindent + "\t") + _.map(o, fn$).join(",\n\t" + iindent) + ("\n" + iindent + "]"));
            } else {
              out.push('"' + key + '": []');
            }
          } else if (o === null) {
            out.push('"' + key + '": null');
          } else {
            out.push('"' + key + '": ' + stringify(o, desired_order, indent + 1));
          }
        }
      }
    }
    return ("{\n" + iindent) + out.join(",\n" + iindent) + ("\n" + _iindent[indent - 1] + "}" + (indent === 1 ? '\n' : ''));
  } else if (indent === 1) {
    return "{}\n";
  } else {
    return "{}";
  }
  function fn$(vv){
    if (typeof vv === 'object') {
      return stringify(vv, desired_order, indent + 1);
    } else {
      return JSON.stringify(vv);
    }
  }
};
da_funk_scopes = [];
da_funk_callthrough = [];
empty_scope = {};
da_funk_callthrough.i = 0;
out$.da_funk = da_funk = function(obj, scope, refs){
  var basename, f, callthrough, i$, ref$, keys, len$, k, v, fn, i, ii, j, jj, args, body;
  if (typeof obj !== 'object') {
    return {};
  }
  refs = typeof refs !== 'object'
    ? {}
    : _.cloneDeep(refs);
  basename = refs.name || '';
  if (typeof refs.__i === 'undefined') {
    refs.__i = 0;
  }
  if (typeof scope !== 'object' || !scope) {
    scope = {};
  }
  f = new Function("if(this !== window && (typeof global !== 'object' || this !== global)) {\n	for (var i in this){\n		eval('var '+i+' = this[i];');\n	}\n}\nreturn function(name, refs, args, body) {\n	var fn = new Function(args, body);\n	var self = this;\n	var f = function() {\n		// try {\n			//console.log(\"this:\", this, \"self:\", self)\n			return fn.apply(this, arguments);\n		/* } catch(e) {\n			var s = (e.stack+'').split('\\n')\n			//var i = 1;\n			var fn_s = fn.toString().split('\\n');\n			var line = /\\:([0-9]+)\\:([0-9]+)\\)$/.exec(s[1])[1] * 1;\n			var sp = \"          \".substr(2, (fn_s.length+'').length);\n			var block = []\n			fn_s.map(function(s, i) {\n				i++;\n				//console.log(i, line, line < (i+3), line, '<', (i+3), line > (i-3), line, '>', (i-3))\n				if(line < (i+3) && line > (i-3)) block.push((i++)+\":\"+sp+s)\n			}).join('\\n')\n			console.error(s[0]+\"\\n(\"+refs.name+\" line: \"+line+\")\\n\"+block.join('\\n'))\n			//debugger;\n			//console.error(\"Exception occured in \"+name, e.stack, fn)\n			//throw e;\n		} */\n	}\n	//f.toString = function() {\n	//	return \"\\ncustom_func: \"+name+\"\\nargs: \"+args+\"\\nbody: \"+body;\n	//}\n	return f\n}");
  callthrough = f.call(scope);
  da_funk_scopes.push(obj);
  for (i$ = 0, len$ = (ref$ = keys = Object.keys(obj)).length; i$ < len$; ++i$) {
    k = ref$[i$];
    v = obj[k];
    if (v === 8 && typeof (fn = obj[k + '.js']) === 'string') {
      i = fn.indexOf('(');
      ii = fn.indexOf(')');
      j = fn.indexOf('{');
      jj = fn.lastIndexOf('}');
      args = fn.substring(++i, ii).replace(regex_space, '');
      refs.name = basename + '.' + k;
      body = '"use strict"\n"' + basename + '"\n' + fn.substring(++j, jj).trim();
      obj[k] = callthrough(k, refs, args, body, new Function(args, body));
    } else if (v && typeof v === 'object' && v !== obj && refs.__i <= (refs.deep || 4) && v.__proto__ === {}.__proto__) {
      refs.name = basename + '.' + k;
      refs.__i++;
      da_funk(obj[k], scope, refs);
      refs.__i--;
    }
  }
  return obj;
};
out$.objectify = objectify = function(str, scope, refs){
  if (!str) {
    return {};
  }
  if (str[0] === '/' || str[0] === '.') {
    str = ToolShed.readFile(str);
  }
  return da_funk(typeof str === 'string' ? JSON.parse(str) : str, scope, refs);
};
out$.merge = merge = function(a, b){
  var keys, i$, len$, k, v, c;
  keys = _.union(Object.keys(a), Object.keys(b));
  for (i$ = 0, len$ = keys.length; i$ < len$; ++i$) {
    k = keys[i$];
    if (b.hasOwnProperty(k)) {
      v = b[k];
      c = a[k];
      a[k] = _.isArray(c)
        ? _.isArray(v)
          ? _.union(v, c)
          : typeof v !== 'undefined' ? c.concat(v) : c
        : _.isObject(v) && _.isObject(c)
          ? merge(c, v)
          : typeof c === 'undefined' ? v : c;
    }
  }
  return a;
};
out$.extend = extend = function(a, b){
  var keys, i$, len$, k, _k, _b, _a, isArray;
  if (typeof b === 'object') {
    keys = Object.keys(b);
    for (i$ = 0, len$ = keys.length; i$ < len$; ++i$) {
      k = keys[i$];
      if (b.hasOwnProperty(k) && k[0] !== '_') {
        _k = k;
        if (k.indexOf('extend.') === 0) {
          _b = b[k];
          k = k.substr("extend.".length);
          _a = a[k];
        } else {
          _b = b[k];
          _a = a[k];
        }
        a[k] = typeof _a === 'function' && (typeof _b === 'function' || (typeof a[_k] === 'function' || (_a = b[_k])))
          ? (isArray = Array.isArray(_a._fnArray))
            ? Array.isArray(_a._fnArray)
              ? (_._fnArray.push(_b), _a)
              : (_a._fnArray = [_a, _b], fn$)
            : _b || _a
          : _.isArray(_a)
            ? _.isArray(_b)
              ? _.union(_b, _a)
              : typeof _b !== 'undefined' ? _a.concat(_b) : _a
            : _a !== _b && typeof _b === 'object' && typeof _a === 'object'
              ? extend(extend({}, _a), _b)
              : _b || _a;
      }
    }
  }
  return a;
  function fn$(){
    "we are _fnArray";
    var i$, ref$, len$, fn, results$ = [];
    for (i$ = 0, len$ = (ref$ = this._fnArray).length; i$ < len$; ++i$) {
      fn = ref$[i$];
      results$.push(fn.apply(this, arguments));
    }
    return results$;
  }
};
out$.embody = embody = function(obj){
  var deps, i, a;
  deps = {};
  i = arguments.length;
  while (i-- > 1) {
    if (_.isObject(a = arguments[i])) {
      deps = extend(deps, a);
    }
  }
  return merge(obj, deps);
};
stringify.get_desired_order = function(path){
  switch (Path.basename(path)) {
  case 'component.json':
  case 'package.json':
    return ['name', 'version', 'description', 'homepage', 'author', 'contributors', 'maintainers'];
  default:
    return [];
  }
};
out$.debug_fn = debug_fn = function(namespace, cb, not_fn){
  if (typeof namespace === 'function') {
    cb = not_fn;
    cb = namespace;
    namespace = void 8;
  }
  return function(){
    if (typeof cb === 'function') {
      if (!namespace || (typeof namespace === 'string' && ~DEBUG.indexOf(namespace)) || (namespace instanceof RegEx && namespace.exec(DEBUG))) {
        debugger;
      }
      return cb.apply(this, arguments);
    } else if (!not_fn) {
      throw new Error("can't debug a function this not really a function");
    }
  };
};
function repeatString$(str, n){
  for (var r = ''; n > 0; (n >>= 1) && (str += str)) if (n & 1) r += str;
  return r;
}