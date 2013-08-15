var _, EventEmitter, Debug, debug, Fiber, Future, slice, NEXT_TRANSITION, NEXT_HANDLER, HANDLING, HANDLED, NO_HANDLER, TRANSITION, INVALID_STATE, DEFERRED, NEW_FSM, utils, Fsm, out$ = typeof exports != 'undefined' && exports || this, slice$ = [].slice;
_ = require('lodash');
EventEmitter = require('events').EventEmitter;
Debug = require('debug');
debug = Debug('fsm');
if (process.versions['node-webkit'] || true) {
  console.log("welcome to webkit Machina");
  Fiber = function(){};
} else {
  Fiber = require('fibers');
  Future = require('fibers/future');
}
slice = [].slice;
NEXT_TRANSITION = 'transition';
NEXT_HANDLER = 'handler';
HANDLING = 'handling';
HANDLED = 'handled';
NO_HANDLER = 'nohandler';
TRANSITION = 'transition';
INVALID_STATE = 'invalidstate';
DEFERRED = 'deferred';
NEW_FSM = 'newfsm';
utils = {
  makeFsmNamespace: function(){
    var machinaCount;
    machinaCount = 0;
    return function(){
      return 'fsm.' + machinaCount++;
    };
  }(),
  getDefaultOptions: function(name){
    return {
      initialState: 'uninitialized',
      eventListeners: {
        '*': []
      },
      muteEvents: false,
      states: {},
      eventQueue: [],
      namespace: name
    };
  }
};
out$.Fsm = Fsm = (function(){
  Fsm.displayName = 'Fsm';
  var debug, prototype = Fsm.prototype, constructor = Fsm;
  function Fsm(name, options){
    this.task = bind$(this, 'task', prototype);
    this.transition = bind$(this, 'transition', prototype);
    this.exec = bind$(this, 'exec', prototype);
    this.transitionSoon = bind$(this, 'transitionSoon', prototype);
    this.emit = bind$(this, 'emit', prototype);
    if (typeof name === 'string') {
      name += '.fsm';
    } else {
      options = name;
      name = utils.makeFsmNamespace();
    }
    debug = Debug(name);
    _.extend(this, options);
    _.defaults(this, utils.getDefaultOptions(name));
    if (this.initialize) {
      this.initialize.apply(this, [options]);
    }
    if (this.initialState) {
      this.transitionSoon(this.initialState);
    }
  }
  prototype.initialize = function(){};
  prototype.concurrency = Infinity;
  prototype.tasks = {};
  prototype.emit = function(eventName){
    var args, doEmit, this$ = this;
    if (this.muteEvents) {
      return;
    }
    args = arguments;
    doEmit = function(){
      var listeners, args1;
      debug("emit: %s", eventName);
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
            return callback.apply(this, args1);
          }, this$);
        }
      }
    };
    if (false && typeof Fiber !== 'undefined') {
      return Fiber(doEmit).run();
    } else {
      return doEmit();
    }
  };
  prototype.emitSoon = function(){
    var a, this$ = this;
    a = arguments;
    return process.nextTick(function(){
      return this$.emit.apply(this$, a);
    });
  };
  prototype.transitionSoon = function(){
    var a, this$ = this;
    a = arguments;
    return process.nextTick(function(){
      return this$.transition.apply(this$, a);
    });
  };
  prototype.exec = function(inputType){
    var states, current, args, handlerName, handler, catchAll, ret, obj;
    debug("handle: %s", inputType);
    if (!this.inExitHandler) {
      states = this.states;
      current = this.state;
      args = slice.call(arguments, 0);
      handlerName = void 8;
      handler = void 8;
      catchAll = void 8;
      ret = void 8;
      this.currentActionArgs = args;
      if (states[current][inputType] || states[current]['*'] || this['*']) {
        handlerName = states[current][inputType] ? inputType : '*';
        catchAll = handlerName === '*';
        if (states[current][handlerName]) {
          handler = states[current][handlerName];
          this._currentAction = current + '.' + handlerName;
        } else {
          handler = this['*'];
          this._currentAction = '*';
        }
        this.emit.call(this, HANDLING, {
          type: inputType,
          args: args.slice(1)
        });
        if (Object.prototype.toString.call(handler) === '[object String]') {
          this.transition(handler);
        } else {
          ret = handler.apply(this, catchAll
            ? args
            : args.slice(1));
        }
        this.emit.call(this, HANDLED, {
          type: inputType,
          args: args.slice(1)
        });
        this._priorAction = this._currentAction;
        this._currentAction = '';
        this.processQueue(NEXT_HANDLER);
      } else {
        obj = {
          type: NEXT_TRANSITION,
          args: args.slice(0)
        };
        this.eventQueue.push(obj);
      }
      this.currentActionArgs = void 8;
      return ret;
    }
  };
  prototype.transition = function(newState){
    var oldState;
    debug("transition %s -> %s", this.state, newState);
    if (!this.inExitHandler && newState !== this.state) {
      oldState = void 8;
      if (this.states[newState]) {
        this.targetReplayState = newState;
        this.priorState = this.state;
        this.state = newState;
        if (oldState = this.priorState) {
          if (this.states[oldState] && this.states[oldState]._onExit) {
            this.inExitHandler = true;
            this.states[oldState]._onExit.call(this);
            this.inExitHandler = false;
          }
          this.emit.call(this, TRANSITION, {
            fromState: oldState,
            toState: newState
          });
        }
        if (this.states[newState]._onEnter) {
          this.states[newState]._onEnter.call(this);
        }
        if (this.targetReplayState === newState) {
          this.processQueue(NEXT_TRANSITION);
        }
        this.processQueue(DEFERRED);
        return;
      }
      debug("attempted to transition to an invalid state: %s", newState);
      return this.emit.call(this, INVALID_STATE, {
        state: this.state,
        attemptedState: newState
      });
    }
  };
  prototype.processQueue = function(type){
    var filterFn, toProcess;
    filterFn = type === NEXT_TRANSITION
      ? function(item){
        return item.type === NEXT_TRANSITION && (!item.untilState || item.untilState === this.state);
      }
      : type === DEFERRED
        ? function(item){
          return item.type === DEFERRED && (!item.untilState || item.untilState === this.state);
        }
        : function(item){
          return item.type === NEXT_HANDLER;
        };
    toProcess = _.filter(this.eventQueue, filterFn, this);
    this.eventQueue = _.difference(this.eventQueue, toProcess);
    return _.each(toProcess, function(item){
      var fn;
      fn = item.type === DEFERRED
        ? item.cb
        : this.exec;
      return fn.apply(this, item.args);
    }, this);
  };
  prototype.clearQueue = function(type, name){
    var filter;
    if (!type) {
      return this.eventQueue = [];
    } else {
      filter = void 8;
      if (type === NEXT_TRANSITION) {
        filter = function(evnt){
          return evnt.type === NEXT_TRANSITION && (name ? evnt.untilState === name : true);
        };
      } else {
        if (type === NEXT_HANDLER) {
          filter = function(evnt){
            return evnt.type === NEXT_HANDLER;
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
        type: DEFERRED,
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
        type: NEXT_TRANSITION,
        untilState: stateName,
        args: this.currentActionArgs
      };
      this.eventQueue.push(queued);
      return this.emit.call(this, DEFERRED, {
        state: this.state,
        queuedArgs: queued
      });
    }
  };
  prototype.deferUntilNextHandler = function(){
    var queued;
    if (this.currentActionArgs) {
      queued = {
        type: NEXT_TRANSITION,
        args: this.currentActionArgs
      };
      this.eventQueue.push(queued);
      return this.emit.call(this, DEFERRED, {
        state: this.state,
        queuedArgs: queued
      });
    }
  };
  prototype.task = function(name){
    var fns, self, task;
    fns = slice$.call(arguments, 1);
    debug("new task '%s'", name);
    self = this;
    task = new EventEmitter;
    task.name = name;
    task.i = 0;
    task.running = 0;
    task.complete = 0;
    task.concurrency = Infinity;
    task.results = [];
    task.chokes = [];
    task.fns = [].concat(fns.slice(0));
    task.branch = function(name){
      var branch;
      branch = self.task(name);
      branch.parent = self;
      task.push(function(done){
        return branch.on('end', function(){
          return done.apply(this, arguments);
        });
      });
      return branch;
    };
    task.choke = function(fn){
      debug("(%s): choke %d", name, this.fns.length);
      this.chokes.push(this.fns.length);
      this.fns.push(fn);
      task.done = false;
      if (this.i) {
        this.next();
      }
      return task;
    };
    task.add = function(fn){
      var i;
      debug("(%s): push %d", name, this.fns.length);
      i = this.fns.length;
      this.fns.splice(i, 0, fn);
      task.done = false;
      this.next();
      return task;
    };
    task.push = function(fn){
      var i;
      debug("(%s): push %d", name, this.fns.length);
      i = this.fns.length;
      /*
      _fn = fn
      fn = (cb) ->
      	console.log i, "before"
      	_cb = cb
      	_fn ->
      		console.log i, "cb"
      		_cb ...
      	console.log i, "after"
      */
      this.fns.push(fn);
      task.done = false;
      if (i) {
        this.next();
      }
      return task;
    };
    task.end = function(cb){
      debug("(%s): end", name);
      task.once('end', cb);
      process.nextTick(function(){
        return task.next();
      });
      return task;
    };
    task.next = function(){
      var i, fn, is_choke, start;
      i = this.i;
      fn = this.fns[i];
      is_choke = ~this.chokes.indexOf(i) ? true : false;
      if (typeof fn === 'undefined' || this.running >= this.concurrency) {
        if (typeof task.parent === 'function') {
          task.parent.next();
        }
        return;
      }
      debug("(%s): running %d %s", name, i, is_choke);
      start = new Date;
      this.i++;
      this.running++;
      fn(function(err, res){
        var end;
        task.running--;
        if (err) {
          console.log("caught err", err.stack);
          task.done = true;
          task.emit('end', err);
        }
        if (task.done) {
          return;
        }
        task.complete++;
        end = new Date;
        if (res) {
          task.results[i] = res;
        }
        debug("(%s): progress %d/%d (%d)", name, task.complete, task.fns.length, task.running);
        task.emit('progress', {
          index: i,
          value: res,
          pending: task.complete - task.fns.length,
          total: task.fns.length,
          complete: task.complete,
          percent: task.complete / task.fns.length * 100 | 0,
          start: start,
          end: end,
          duration: end - start
        });
        if (task.complete < task.fns.length) {
          return task.next();
        } else {
          return task.emit('end', null, task.results, name);
        }
      });
      if (!is_choke && task.complete < task.fns.length) {
        return task.next();
      }
    };
    return this.tasks[name] = task;
  };
  prototype.promt = function(name, q){
    console.log("prompting...");
    this.emit('prompt', name, q);
    return this.emit('prompt:' + name, q);
  };
  prototype.on = function(eventName, real_cb, callback){
    var self, listeners;
    if (typeof callback === 'undefined') {
      callback = real_cb;
    }
    self = this;
    listeners = self.eventListeners[eventName];
    if (!listeners) {
      self.eventListeners[eventName] = [];
    }
    if (typeof listeners === 'function') {
      self.eventListeners[eventName] = [listeners];
    }
    self.eventListeners[eventName].push(callback);
    return {
      eventName: eventName,
      callback: callback,
      cb: real_cb,
      off: function(){
        return self.off(eventName, callback);
      }
    };
  };
  prototype.once = function(eventName, callback){
    var lala;
    return lala = this.on(eventName, callback, function(){
      lala.cb.apply(this, arguments);
      process.nextTick(function(){
        return lala.off();
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
/*
# testing
fsm = new Fsm {
	states:
		uninitialized:
			_onEnter: ->
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
			_onEnter: ->
				console.log "uninitialized"
				task = @task 'lala2'
				task.push (done) -> done null, 1
				task.end (err, res) ->
					console.log "task end", &

}
#*/
function bind$(obj, key, target){
  return function(){ return (target || obj)[key].apply(obj, arguments) };
}