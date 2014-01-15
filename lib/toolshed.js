var Fs, Path, Url, spawn, _, mkdirp, printf, EventEmitter, nw_version, v8_version, HOME_DIR, v8_mode, Debug, debug, Fiber, Future, scan, parse, isDirectory, unquote, isQuoted, stripEscapeCodes, mkdir, exists, stat, readdir, readFile, writeFile, exec, searchDownwardFor, recursive_hardlink, Scope, Config, stringify, out$ = typeof exports != 'undefined' && exports || this;
Fs = require('fs');
Path = require('path');
Url = require('url');
spawn = require('child_process').spawn;
out$._ = _ = require('lodash');
mkdirp = require('mkdirp');
printf = require('printf');
out$.EventEmitter = EventEmitter = require('events').EventEmitter;
out$.nw_version = nw_version = process.versions['node-webkit'];
out$.v8_version = v8_version = (nw_version ? 'nw' : 'node') + '_' + process.platform + '_' + process.arch + '_' + process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/)[0] + '-' + process.versions.modules;
out$.HOME_DIR = HOME_DIR = process.platform === 'win32'
  ? process.env.USERPROFILE
  : process.env.HOME;
out$.v8_mode = v8_mode = 'Release';
out$.Debug = Debug = function(prefix){
  var path, debug;
  if (!(path = Debug.prefixes[prefix])) {
    path = process.cwd();
  }
  path = Path.join(HOME_DIR, '.verse', 'debug.log');
  debug = function(){
    var msg;
    msg = printf.apply(this, arguments);
    Fs.appendFileSync(path, prefix + ": " + msg + "\n");
  };
  mkdirp(Path.dirname(path), function(err){
    Fs.writeFileSync(path, "");
    return debug("starting...");
  });
  return debug;
};
Debug.prefixes = {};
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
          : stringify(obj, 1, stringify.get_desired_order(path));
        if (json_str !== written_json_str) {
          debug("writing...", path);
          writeFile(path, json_str, function(err){
            written_json_str = json_str;
            if (typeof save_fn === 'function') {
              save_fn(obj);
            }
            ee.emit('save', obj, path, json_str);
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
  if (initial_obj) {
    _.each(initial_obj, function(v, k){
      if (typeof v === 'object' && v !== null) {
        return config[k] = make_reflective(v, k, save);
      } else {
        return Config._[path][k] = v;
      }
    });
  }
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
    if (data) {
      config.emit('ready', config, data);
    } else {
      save();
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
out$.stringify = stringify = function(obj, indent, desired_order){
  var out, iindent, k, doi, i, kk, i$, len$, key, o;
  indent == null && (indent = 1);
  desired_order == null && (desired_order = []);
  out = [];
  iindent = repeatString$('\t', indent);
  k = Object.keys(obj).sort();
  if ((doi = desired_order.length - 1) >= 0) {
    do {
      if (~(i = k.indexOf(desired_order[doi]))) {
        kk = k.splice(i, 1);
        k.unshift(kk[0]);
      }
    } while (--doi >= 0);
  }
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
        if (key === 'keywords' || typeof o.length === 'number' || Array.isArray(o)) {
          out.push('"' + key + ("\": [\n" + iindent + "\t") + _.map(o, fn$).join(",\n\t" + iindent) + ("\n" + iindent + "]"));
        } else if (o === null) {
          out.push('"' + key + '": null');
        } else {
          out.push('"' + key + '": ' + stringify(o, indent + 1));
        }
      }
    }
  }
  return ("{\n" + iindent) + out.join(",\n" + iindent) + ("\n" + repeatString$('\t', indent - 1) + "}");
  function fn$(vv){
    if (typeof vv === 'object') {
      return stringify(vv, indent + 1);
    } else {
      return JSON.stringify(vv);
    }
  }
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
function repeatString$(str, n){
  for (var r = ''; n > 0; (n >>= 1) && (str += str)) if (n & 1) r += str;
  return r;
}