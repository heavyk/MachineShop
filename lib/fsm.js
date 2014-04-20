var assert, Semver, ToolShed, Debug, _, EventEmitter, debug, slice, Fabuloso, Fsm, Machina, _machina, out$ = typeof exports != 'undefined' && exports || this;
assert = require('assert');
Semver = require('semver');
ToolShed = require('./toolshed');
Debug = ToolShed.Debug, _ = ToolShed._, EventEmitter = ToolShed.EventEmitter;
debug = Debug('Fsm');
slice = [].slice;
({
  makeFsmNamespace: function(){
    var machinaCount;
    machinaCount = 0;
    return function(){
      return 'fsm.' + machinaCount++;
    };
  }()
});
Fabuloso = {
  derivitave: function(name, version){
    if (version) {
      return Semver.version(version, this._derivitaves[name]);
    } else {
      return this._derivitaves[name];
    }
  },
  derivitaves: {
    'node-webkit': function(cb){
      return cb(typeof process === 'object' && typeof process.versions === 'object' ? process.versions['node-webkit'] : void 8);
    },
    node: function(cb){
      return cb(typeof process === 'object' && typeof process.versions === 'object' ? process.versions.node : void 8);
    },
    browser: function(cb){
      return cb(typeof window.navigator === 'object' ? window.navigator.version : void 8);
    }
  },
  'extend.initialize': function(){
    var task;
    if (typeof this._derivitaves === 'undefined') {
      this._derivitaves = {};
    }
    task = this.task('check derivitaves');
    _.each(this.derivitaves, function(d, k){
      return task.push("checking for " + k, function(done){
        var self;
        self = this;
        return d(function(v){
          if (v) {
            self._derivitaves[k] = v;
            self.debug("found derivitave " + k + "@" + v);
          }
          return done(void 8, v);
        });
      });
    });
    task.end(function(){
      if (this.state) {
        this.debug("re-emit " + this.initialState);
        return this.emit('transition', {
          toState: this.initialState
        });
      }
    });
  }
};
out$.Fsm = Fsm = (function(){
  Fsm.displayName = 'Fsm';
  var total_deferred, prototype = Fsm.prototype, constructor = Fsm;
  total_deferred = 0;
  function Fsm(name, options){
    var i$, ref$, len$, fn, key;
    this.once = bind$(this, 'once', prototype);
    this.on = bind$(this, 'on', prototype);
    this.emit = bind$(this, 'emit', prototype);
    this.emitSoon = bind$(this, 'emitSoon', prototype);
    this.transitionSoon = bind$(this, 'transitionSoon', prototype);
    this.execSoon = bind$(this, 'execSoon', prototype);
    this.exec = bind$(this, 'exec', prototype);
    this.error = bind$(this, 'error', prototype);
    this.reset = bind$(this, 'reset', prototype);
    this.once_initialized = bind$(this, 'once_initialized', prototype);
    if (typeof name === 'string') {
      name += '.fsm.' + Math.random().toString(32).substr(2);
    } else {
      options = name;
      name = makeFsmNamespace();
    }
    this.debug = Debug(name);
    this.debug("new Fsm!");
    if (_machina) {
      _machina.emit('new:Fsm', this);
    }
    this.tasks = {};
    if (typeof options === 'object') {
      ToolShed.extend(this, options);
    }
    if (!this.eventListeners) {
      this.eventListeners = {};
    }
    if (!this.eventQueue) {
      this.eventQueue = [];
    }
    if (!this.states) {
      console.log("@", this);
      throw new Error("really, a stateless state machine???");
      this.states = {};
    }
    if (!this.namespace) {
      this.namespace = name;
    }
    if (typeof this.initialState === 'undefined') {
      this.initialState = 'uninitialized';
    }
    switch (typeof this.initialize) {
    case 'function':
      this.initialize.call(this, options);
      break;
    case 'object':
      if (Array.isArray(this.initialize)) {
        for (i$ = 0, len$ = (ref$ = this.initialize).length; i$ < len$; ++i$) {
          fn = ref$[i$];
          if (typeof fn === 'function') {
            fn.call(this, options);
          }
        }
      } else {
        for (key in ref$ = this.initialize) {
          fn = ref$[key];
          if (typeof fn === 'function') {
            fn.call(this, options);
          }
        }
      }
    }
    this.debug("fsm state " + this.state);
    if (!this.state) {
      this.transition(this.initialState);
    }
  }
  prototype.muteEvents = false;
  prototype.concurrency = Infinity;
  prototype._initialized = false;
  prototype.once_initialized = function(cb){
    assert(this instanceof Fsm);
    this.debug("once_initialized... %s", this._initialized);
    if (typeof cb === 'function') {
      if (this._initialized) {
        cb.call(this);
      } else {
        this.eventQueue.push({
          type: 'deferred',
          notState: this.initialState,
          cb: cb
        });
      }
    }
    return this._initialized;
  };
  prototype.reset = function(){
    this.state = void 8;
    if (typeof this.initialize === 'function') {
      this.initialize.call(this);
    }
    if (this.initialState) {
      return this.transitionSoon(this.initialState);
    }
  };
  prototype.error = function(err){
    var states, estate;
    states = this.states;
    if (estate = states[this.state].onerror) {
      return this.states[this.state].onerror.call(this);
    } else {
      return console.error(err.stack) || err + '';
    }
  };
  prototype.exec = function(cmd){
    var states, state, args, args1, handlerName, handler, catchAll, ret, obj;
    this.debug("exec: (%s:%s)", this.state, cmd);
    if (!this.inExitHandler) {
      states = this.states;
      state = this.state;
      args = slice.call(arguments, 0);
      args1 = args.slice(1);
      handlerName = void 8;
      handler = void 8;
      catchAll = void 8;
      ret = void 8;
      this.currentActionArgs = args;
      if (state && (states[state][cmd] || states[state]['*'] || this['*']) || this.cmds && typeof (handler = this.cmds[cmd]) === 'function') {
        if (state && (handlerName = states[state][cmd] ? cmd : '*') && (handler = states[state][handlerName])) {
          this._currentAction = state + '.' + handlerName;
        } else if (this.cmds && typeof (handler = this.cmds[cmd]) === 'function') {
          this._currentAction = handlerName = cmd;
        } else {
          handler = this['*'];
          this._currentAction = '*';
        }
        this.emit.call(this, 'executing', {
          type: cmd,
          args: args1
        });
        if (Object.prototype.toString.call(handler) === '[object String]') {
          this.debug("exec bullshit:transition (%s)", handler);
          this.debug.todo("I think this is loke a forwarder... look into it and make sure. lala: mycmd: 'lala.lala' should transition to 'lala.lalai or it should call lala: lala: -> console.log 'hello world'");
          this.debug.todo("wait, this might mean that an exec that is lala: lala: 'mmm' -> transition \\mmm");
          this.transition(handler);
        } else {
          ret = handler.apply(this, handlerName === '*' ? args : args1);
          this.debug("exec called:ret (%s)", ret);
        }
        this.emit.call(this, 'executed', {
          type: cmd,
          args: args1,
          ret: ret
        });
        this._priorAction = this._currentAction;
        this._currentAction = '';
        this.processQueue('next-exec');
      } else {
        this.debug("exec: next transition");
        obj = {
          type: 'next-transition',
          cmd: cmd,
          args: args.slice(0)
        };
        this.eventQueue.push(obj);
      }
      this.currentActionArgs = void 8;
      return ret;
    }
  };
  prototype.execSoon = function(){
    var a, this$ = this;
    a = arguments;
    return process.nextTick(function(){
      return this$.exec.apply(this$, a);
    });
  };
  prototype.transitionSoon = function(){
    var a, this$ = this;
    a = arguments;
    return process.nextTick(function(){
      return this$.transition.apply(this$, a);
    });
  };
  prototype.transition = function(newState){
    var oldState, args1, args;
    if (typeof newState !== 'string') {
      newState = newState + '';
    }
    if (this.inTransition) {
      return this.transitionSoon.apply(this, arguments);
    }
    this.debug("fsm: transition %s -> %s", this.state, newState);
    if (!this.inExitHandler && newState !== this.state) {
      oldState = void 8;
      args1 = slice.call(arguments, 1);
      if (this.states[newState]) {
        this.inTransition = newState;
        this.targetReplayState = newState;
        this.priorState = this.state;
        this.state = newState;
        if (oldState = this.priorState) {
          if (this.states[oldState] && this.states[oldState].onexit) {
            this.inExitHandler = true;
            this.states[oldState].onexit.apply(this, args1);
            this.inExitHandler = false;
          }
        }
        if (this.states[newState].onenter) {
          this.states[newState].onenter.apply(this, args1);
        }
        if (oldState === this.initialState && !this._initialized) {
          this.debug("%s initialzed! in %s", this.namespace, newState);
          this._initialized = true;
        }
        this.debug("fsm: post-transition %s -> %s", oldState, newState);
        this.emit.apply(this, ["state:" + newState].concat(args1));
        this.emit.call(this, 'transition', {
          fromState: oldState,
          toState: newState,
          args: args = args1
        });
        this.processQueue.call(this, 'next-transition');
        this.processQueue.call(this, 'deferred');
        return this.inTransition = null;
      } else {
        this.debug("attempted to transition to an invalid state: %s", newState);
        return this.emit.call(this, 'invalid-state', {
          state: this.state,
          attemptedState: newState,
          args: args1
        });
      }
    }
  };
  prototype.processQueue = function(type){
    var filterFn, len_before, toProcess, this$ = this;
    filterFn = type === 'next-transition'
      ? function(item){
        return item.type === 'next-transition' && typeof this$.states[this$.state][item.cmd] !== 'undefined';
      }
      : type === 'deferred'
        ? function(item, i){
          return item.type === 'deferred' && ((item.untilState && item.untilState === this$.state) || (item.notState && item.notState !== this$.state));
        }
        : function(item){
          return item.type === 'next-exec';
        };
    len_before = this.eventQueue.length;
    toProcess = _.filter(this.eventQueue, filterFn);
    _.each(toProcess, function(item){
      var fn, i;
      if (filterFn(item, i)) {
        fn = item.type === 'deferred'
          ? item.cb
          : this$.exec;
        fn.apply(this$, item.args);
        i = this$.eventQueue.indexOf(item);
        this$.eventQueue.splice(i, 1);
      }
    });
  };
  prototype.clearQueue = function(type, name){
    var filter, this$ = this;
    if (!type) {
      return this.eventQueue = [];
    } else {
      filter = void 8;
      if (type === 'next-transition') {
        filter = function(evnt){
          return evnt.type === 'next-transition' && (name ? evnt.untilState === name : true);
        };
      } else {
        if (type === 'next-exec') {
          filter = function(evnt){
            return evnt.type === 'next-exec';
          };
        }
      }
      return this.eventQueue = _.filter(this.eventQueue, filter);
    }
  };
  prototype.until = function(stateName, cb){
    var args, queued;
    args = slice.call(arguments, 2);
    if (this.state === stateName) {
      return cb.apply(this, args);
    } else {
      queued = {
        type: 'deferred',
        untilState: stateName,
        cb: cb,
        args: args
      };
      return this.eventQueue.push(queued);
    }
  };
  prototype.deferUntilTransition = function(stateName){
    var queued;
    if (this.currentActionArgs) {
      queued = {
        type: 'next-transition',
        untilState: stateName,
        args: this.currentActionArgs
      };
      this.eventQueue.push(queued);
      return this.emit.call(this, 'deferred', {
        state: this.state,
        queuedArgs: queued
      });
    }
  };
  prototype.deferUntilNextHandler = function(){
    var queued;
    if (this.currentActionArgs) {
      queued = {
        type: 'next-transition',
        args: this.currentActionArgs
      };
      this.eventQueue.push(queued);
      return this.emit.call(this, 'deferred', {
        state: this.state,
        queuedArgs: queued
      });
    }
  };
  prototype.task = function(name){
    var self, task;
    this.debug("new task '%s'", name);
    self = this;
    task = new EventEmitter;
    task.name = name;
    task.i = 0;
    task.running = 0;
    task.complete = 0;
    task.concurrency = Infinity;
    task.results = [];
    task.msgs = [];
    task.chokes = [];
    task.fns = [];
    task.branch = function(name){
      var branch;
      branch = self.task(name);
      branch.parent = self;
      return branch;
    };
    task.choke = function(txt, fn){
      if (typeof txt === 'function') {
        fn = txt;
        txt = null;
      }
      self.debug("task(%s): choke %d", name, task.fns.length);
      task.chokes.push(task.fns.length);
      task.fns.push(fn);
      task.msgs.push(txt);
      task.done = false;
      if (task.i) {
        task.next();
      }
      return task;
    };
    task.add = function(txt, fn){
      var i;
      if (typeof txt === 'function') {
        fn = txt;
        txt = null;
      }
      i = task.fns.length;
      task.fns.splice(i, 0, fn);
      task.msgs.splice(i, 0, txt);
      task.done = false;
      task.next();
      return task;
    };
    task.push = function(txt, fn){
      var i;
      if (typeof txt === 'function') {
        fn = txt;
        txt = null;
      }
      i = task.fns.length;
      task.fns.push(fn);
      task.msgs.push(txt);
      task.done = false;
      if (task.i !== 0) {
        task.next();
      }
      return task;
    };
    task.end = function(cb){
      self.debug("task(%s): end", name);
      task.cb = cb;
      if (task.fns.length) {
        return task.next();
      } else {
        task.done = true;
        return cb.call(self, null, task.results, name);
      }
    };
    task.next = function(){
      var i, fn, is_choke, start;
      i = task.i;
      fn = task.fns[i];
      is_choke = ~task.chokes.indexOf(i) ? true : false;
      if (typeof fn === 'undefined' || task.running >= task.concurrency || (is_choke && task.running !== 0)) {
        if (typeof task.parent === 'function') {
          task.parent.next();
        }
        self.debug("task(%s): waiting #%d (running:%s/%s) choke:%s - %s", name, i, task.running, task.concurrency, is_choke, typeof fn);
        return;
      }
      start = new Date;
      task.i++;
      task.running++;
      self.debug("task(%s): running... #%s (complete:%d/%d) (%s)", name, i, task.complete, task.fns.length, task.msgs[i]);
      task.emit('running', {
        msg: task.msgs[i],
        index: i,
        running: task.running,
        pending: {
          pending: task.complete - task.fns.length
        },
        total: task.fns.length
      });
      fn.call(self, function(err, res){
        var end, ref$, ref1$;
        task.running--;
        if (err) {
          task.done = true;
          if (typeof task.cb === 'function') {
            task.cb.call(self, err);
          }
          task.emit('error', err);
          return;
        }
        task.complete++;
        end = new Date;
        if (res) {
          task.results[i] = res;
        }
        self.debug("task(%s): done #%s (complete:%d/%d running:%d) (%s)", name, i, task.complete, task.fns.length, task.running, task.msgs[i]);
        task.emit('complete', {
          index: i,
          value: res,
          pending: task.complete - task.fns.length,
          total: task.fns.length,
          complete: task.complete,
          msg: task.msgs[i],
          percent: task.complete / task.fns.length * 100 | 0,
          start: start,
          end: end,
          duration: end - start
        });
        if (task.running + task.complete < task.fns.length) {
          return process.nextTick(function(){
            return task.next();
          });
        } else if (task.running === 0) {
          if (typeof task.cb === 'function') {
            self.debug("task(%s): completed all tasks %d/%d", name, task.complete, task.fns.length);
            task.cb.call(self, null, task.results, name);
          }
          task.emit('end', null, task.results, name);
          return ref1$ = (ref$ = self.tasks)[name], delete ref$[name], ref1$;
        }
      });
      if (!is_choke && task.running + task.complete < task.fns.length) {
        return task.next();
      }
    };
    task.emit('task:new', task);
    if (this.tasks[name]) {
      throw new Error("task already exists");
    }
    return this.tasks[name] = task;
  };
  prototype.emitSoon = function(){
    var a, this$ = this;
    a = arguments;
    return process.nextTick(function(){
      return this$.emit.apply(this$, a);
    });
  };
  prototype.emit = function(eventName){
    var args, doEmit, this$ = this;
    if (this.muteEvents) {
      return;
    }
    args = arguments;
    doEmit = function(){
      var ref$, listeners, args1;
      switch (eventName) {
      case 'executing':
        this$.debug("executing: (%s:%s)", this$.state, (ref$ = args[1]) != null ? ref$.type : void 8);
        break;
      case 'executed':
        this$.debug("executed: (%s:%s)", this$.state, (ref$ = args[1]) != null ? ref$.type : void 8);
        break;
      case 'invalid-state':
        this$.debug.error("bad transition: (%s !-> %s)", args[1].state, args[1].attemptedState);
        break;
      case 'transition':
        this$.debug("transition: (%s -> %s)", args[1].fromState, args[1].toState);
        break;
      default:
        this$.debug("emit: (%s): num args %s", eventName, args.length - 1);
      }
      if (listeners = this$.eventListeners['*']) {
        if (typeof listeners === 'function') {
          listeners.apply(this$, args);
        } else {
          _.each(this$.eventListeners['*'], function(callback){
            return callback.apply(this, args);
          }, this$);
        }
      }
      if (listeners = this$.eventListeners[eventName]) {
        args1 = slice.call(args, 1);
        if (typeof listeners === 'function') {
          return listeners.apply(this$, args1);
        } else {
          return _.each(listeners, function(callback){
            return callback.apply(this$, args1);
          });
        }
      }
    };
    doEmit.call(this);
    return this;
  };
  prototype.on = function(eventName, real_cb, callback){
    var listeners, this$ = this;
    if (typeof callback !== 'function') {
      callback = real_cb;
      real_cb = void 8;
    }
    listeners = this.eventListeners[eventName];
    if (this.eventListeners === this.__proto__.eventListeners) {
      this.eventListeners = _.cloneDeep(this.eventListeners);
    }
    if (!listeners) {
      this.eventListeners[eventName] = [];
    }
    if (typeof listeners === 'function') {
      this.eventListeners[eventName] = [listeners];
    }
    this.eventListeners[eventName].push(callback);
    if (eventName.substr(0, 6) === "state:" && this.state === eventName.substr(6)) {
      process.nextTick(function(){
        return callback.call(this$);
      });
    }
    return {
      eventName: eventName,
      callback: callback,
      cb: real_cb,
      off: function(){
        return this$.off(eventName, callback);
      }
    };
  };
  prototype.once = function(eventName, callback){
    var evt, this$ = this;
    return evt = this.on(eventName, callback, function(){
      evt.cb.apply(this$, arguments);
      process.nextTick(function(){
        return evt.off(eventName, callback);
      });
    });
  };
  prototype.off = function(eventName, callback){
    var i;
    if (!eventName) {
      return this.eventListeners = {};
    } else {
      if (this.eventListeners[eventName]) {
        if (callback) {
          if (~(i = this.eventListeners[eventName].indexOf(callback))) {
            return this.eventListeners[eventName].splice(i, 1);
          }
        } else {
          return this.eventListeners[eventName] = [];
        }
      }
    }
  };
  return Fsm;
}());
Machina = (function(superclass){
  var prototype = extend$((import$(Machina, superclass).displayName = 'Machina', Machina), superclass).prototype, constructor = Machina;
  prototype.fsms = [];
  function Machina(name){
    console.log("yay! we are a new Machina");
    Machina.superclass.call(this, "Machina");
    ToolShed.extend(this, Fabuloso);
  }
  prototype.eventListeners = {
    newfsm: function(fsm){
      return this.fsms.push(fsm);
    }
  };
  prototype.states = {
    uninitialized: {
      onenter: function(){
        return this.transition('ready');
      }
    },
    ready: {
      onenter: function(){
        return this.debug("machina ready!");
      }
    }
  };
  return Machina;
}(Fsm));
_machina = new Machina;
Object.defineProperty(exports, "Machina", {
  get: function(){
    if (!_machina) {
      _machina = new Machina;
    }
    return _machina;
  }
});
/*
#TODO: convert this into a real test...
fsm = new Fsm {
	states:
		uninitialized:
			onenter: ->
				console.log "uninitialized"
				task = @task 'lala1'
				task.choke (done) ->
					setTimeout ->
						done null, 1
					, 1500
				task.push (done) ->
					setTimeout ->
						done null, 2
					, 1600
				task.push (done) ->
					setTimeout ->
						done null, 3
					, 1700
				task.push (done) ->
					setTimeout ->
						done null, 4
					, 1800
				task.push (done) ->
					setTimeout ->
						done null, 5
					, 1900
				task.push (done) ->
					setTimeout ->
						done null, 6
					, 2000

				sub1 = task.branch 'sub1'
				sub1.push (done) -> done null, 1
				sub1.push (done) ->
					setTimeout ->
						done null, 1
					, 2500
				sub1.push (done) ->
					setTimeout ->
						done null, 2
					, 3000
				sub1.choke (done) ->
					setTimeout ->
						done null, 3
					, 1000
				sub1.push (done) ->
					setTimeout ->
						done null, 5
					, 3000
				sub1.push (done) ->
					setTimeout ->
						done null, 4
					, 1000
				task.push (done) -> sub1.end done

				task.push (done) -> done null, 6
				#(err, res) <- task.end
				console.log "here", &
				task.choke (done) ->
					setTimeout ->
						done null, 7
					, 2000
				#(err, res) <- task.end
				task.choke (done) ->
					setTimeout ->
						done null, 8
					, 2000

				task.end (err, res) ->
					console.log "task end", &

}
#*/
/*
fsm = new Fsm {
	states:
		uninitialized:
			onenter: ->
				console.log "uninitialized"
				task = @task 'lala2'
				task.push (done) -> done null, 1
				task.end (err, res) ->
					console.log "task end", &

}
#*/
out$.Fabuloso = Fabuloso;
out$.Fsm = Fsm;
function bind$(obj, key, target){
  return function(){ return (target || obj)[key].apply(obj, arguments) };
}
function extend$(sub, sup){
  function fun(){} fun.prototype = (sub.superclass = sup).prototype;
  (sub.prototype = new fun).constructor = sub;
  if (typeof sup.extended == 'function') sup.extended(sub);
  return sub;
}
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}