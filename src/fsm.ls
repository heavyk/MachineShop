_ = require 'lodash'
EventEmitter = require \events .EventEmitter
Debug = require \debug
debug = Debug 'Fsm'

# inspired by ifandelse'a machina.js
#  https://github.com/ifandelse/machina.js
# and visionmedia's batch
#  https://github.com/visionmedia/batch


slice = [].slice
NEXT_TRANSITION = 'transition'
NEXT_HANDLER = 'handler'
HANDLING = 'handling'
HANDLED = 'handled'
NO_HANDLER = 'nohandler'
TRANSITION = 'transition'
INVALID_STATE = 'invalidstate'
DEFERRED = 'deferred'
NEW_FSM = 'newfsm'
utils = {
	makeFsmNamespace: (->
		machinaCount = 0
		-> 'fsm.' + machinaCount++
	)!
	getDefaultOptions: (name) ->
		{
			initialState: 'uninitialized'
			eventListeners: {'*': []}
			muteEvents: false
			states: {}
			eventQueue: []
			namespace: name
		}
}

# https://github.com/ifandelse/machina.js
# v0.3.2
# modified eventListeners to accept a function, but convert to an array if more than one is found
# TODO: this should be improved...
#   there will be problems using the 'off' function and the 'on' function can be optimized as well
# TODO: add fsm logging capability (and show this log inside of verse)

export class Fsm
	var debug
	(name, options) ->
		if typeof name is \string
			name += '.fsm'
		else
			options = name
			name = utils.makeFsmNamespace!
		debug := Debug name
		_.extend @, options
		_.defaults @, utils.getDefaultOptions name
		@initialize.apply @, [options] if @initialize
		#machina.emit NEW_FSM, @
		@transitionSoon @initialState if @initialState

	initialize: ->
	# make getter / setter?
	concurrency: Infinity
	tasks: {}
	emit: (eventName) ~>
		if @muteEvents then return
		args = &
		doEmit = ~>
			debug "emit: %s", eventName
			if listeners = @eventListeners.'*'
				if typeof listeners is \function then listeners.apply this, args
				else _.each @eventListeners.'*', ((callback) -> callback.apply this, args), this
			if listeners = @eventListeners[eventName]
				args1 = slice.call args, 1
				if typeof listeners is \function then listeners.apply this, args1
				else _.each listeners, ((callback) -> callback.apply this, args1), this
		doEmit!
	emitSoon: -> a = &; process.nextTick ~> @emit.apply @, a
	transitionSoon: ~> a = &; process.nextTick ~> @transition.apply @, a
	exec: (inputType) ~>
		debug "exec: %s::%s", @state, inputType
		if not @inExitHandler
			states = @states
			current = @state
			args = slice.call &, 0
			handlerName = void
			handler = void
			catchAll = void
			ret = void
			@currentActionArgs = args
			if current and (states[current][inputType] or states[current].'*' or @.'*')
				handlerName = if states[current][inputType] then inputType else '*'
				catchAll = handlerName is '*'
				if states[current][handlerName]
					handler = states[current][handlerName]
					@_currentAction = current + '.' + handlerName
				else
					handler = @.'*'
					@_currentAction = '*'
				@emit.call this, HANDLING, {
					type: inputType
					args: args.slice 1
				}
				if (Object::toString.call handler) is '[object String]'
					@transition handler
				else ret = handler.apply this, if catchAll then args else args.slice 1
				@emit.call this, HANDLED, {
					type: inputType
					args: args.slice 1
				}
				@_priorAction = @_currentAction
				@_currentAction = ''
				@processQueue NEXT_HANDLER
			else
				obj = {
					type: NEXT_TRANSITION
					#untilState: inputType
					args: args.slice 0
				}
				#debug "no handler (#{@state}).#{inputType}"
				#if @emit.call(this, NO_HANDLER, obj) isnt false
				@eventQueue.push obj
			@currentActionArgs = void
			return ret
	transition: (newState) ~>
		debug "transition %s -> %s", @state, newState
		if not @inExitHandler and newState isnt @state
			oldState = void
			if @states[newState]
				@targetReplayState = newState
				@priorState = @state
				@state = newState
				if oldState = @priorState
					if @states[oldState] and @states[oldState]._onExit
						@inExitHandler = true
						@states[oldState]._onExit.call this
						@inExitHandler = false
				if @states[newState]._onEnter
					@states[newState]._onEnter.call this
				@emit.call this, TRANSITION, {
					fromState: oldState
					toState: newState
				}
				if @targetReplayState is newState then @processQueue NEXT_TRANSITION
				#@processQueue NEXT_TRANSITION
				@processQueue DEFERRED
				return
			debug "attempted to transition to an invalid state: %s", newState
			#TODO: when the state machine is virtualized, ask the user to add the state
			@emit.call this, INVALID_STATE, {
				@state
				attemptedState: newState
			}
	processQueue: (type) ->
		#console.log "processQueue", NEXT_TRANSITION, NEXT_HANDLER
		filterFn = if type is NEXT_TRANSITION
			(item) -> item.type is NEXT_TRANSITION and (not item.untilState or item.untilState is @state)
		else if type is DEFERRED
			(item) -> item.type is DEFERRED and (not item.untilState or item.untilState is @state)
		else
			(item) -> item.type is NEXT_HANDLER
		toProcess = _.filter @eventQueue, filterFn, this
		@eventQueue = _.difference @eventQueue, toProcess
		_.each toProcess, ((item) ->
			fn = if item.type is DEFERRED => item.cb else @exec
			fn.apply this, item.args
		), this
	clearQueue: (type, name) ->
		if not type
			@eventQueue = []
		else
			filter = void
			if type is NEXT_TRANSITION
				filter = (evnt) -> evnt.type is NEXT_TRANSITION and if name then evnt.untilState is name else true
			else
				if type is NEXT_HANDLER then filter = (evnt) -> evnt.type is NEXT_HANDLER
			@eventQueue = _.filter @eventQueue, filter
	until: (stateName, cb) ->
		args = slice.call &, 2
		if @state is stateName
			cb.apply this, args
		else
			queued = {
				type: DEFERRED
				untilState: stateName
				cb: cb
				args: args
			}
			@eventQueue.push queued
	deferUntilTransition: (stateName) ->
		if @currentActionArgs
			queued = {
				type: NEXT_TRANSITION
				untilState: stateName
				args: @currentActionArgs
			}
			@eventQueue.push queued
			@emit.call this, DEFERRED, {
				@state
				queuedArgs: queued
			}
	deferUntilNextHandler: ->
		if @currentActionArgs
			queued = {
				type: NEXT_TRANSITION
				args: @currentActionArgs
			}
			@eventQueue.push queued
			@emit.call this, DEFERRED, {
				@state
				queuedArgs: queued
			}
	task: (name) ~>
		debug "new task '%s'", name
		#OPTIMIZE: do we really need the 'self' variable? it's only used in the branch fn
		#  once tests are implemented, we can check to be sure
		self = this
		task = new EventEmitter
		task.name = name
		task.i = 0
		task.running = 0
		task.complete = 0
		task.concurrency = Infinity
		task.results = []
		task.msgs = []
		task.chokes = []
		task.fns = []
		task.branch = (name) ->
			if typeof txt is \function
				fn = txt
				txt = null
			branch = self.task name
			branch.parent = self
			task.push (done) ->
				branch.on \end ->
					done ...
			branch
		task.choke = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			debug "(%s): choke %d", name, @fns.length
			@chokes.push @fns.length
			@fns.push fn
			@msgs.push txt
			task.done = false
			if @i
				@next!
			task
		task.add = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			debug "(%s): add %d", name, @fns.length
			i = @fns.length
			@fns.splice i, 0, fn
			@msgs.splice i, 0, txt
			task.done = false
			@next!
			task
		task.push = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			debug "(%s): push %d", name, @fns.length
			i = @fns.length
			@fns.push fn
			@msgs.push txt
			task.done = false
			if i then @next!
			task
		task.end = (cb) ->
			debug "(%s): end", name
			task.once \end cb
			process.nextTick ->
				task.next!
			task
		task.next = ->
			i = @i
			fn = @fns[i]
			is_choke = if ~@chokes.indexOf i then true else false
			if typeof fn is \undefined or @running >= @concurrency
				if typeof task.parent is \function then task.parent.next!
				return # @onend null, @results, name
			debug "(%s): running %d %s", name, i, is_choke
			start = new Date
			@i++
			@running++
			@emit \running @msg = @msgs[i], i, @fns.length
			fn (err, res) ->
				task.running--
				if err
					console.log "caught err", err.stack
					task.done = true
					task.emit \end, err
				return if task.done
				task.complete++
				end = new Date
				task.results[i] = res if res
				debug "(%s): progress %d/%d (%d)", name, task.complete, task.fns.length, task.running
				task.emit \progress, {
					index: i
					value: res
					pending: task.complete - task.fns.length
					total: task.fns.length
					complete: task.complete
					msg: task.msg
					percent: task.complete / task.fns.length * 100 .|. 0
					start: start
					end: end
					duration: end - start
				}
				if task.complete < task.fns.length then task.next!
				else task.emit \end, null, task.results, name
			if not is_choke and task.complete < task.fns.length then task.next!
		@tasks[name] = task

	promt: (name, q) ->
		console.log "prompting..."
		@emit 'prompt', name, q
		@emit 'prompt:'+name, q
	on: (eventName, real_cb, callback) ->
		if typeof callback is \undefined then callback = real_cb
		self = this
		listeners = self.eventListeners[eventName]
		self.eventListeners[eventName] = [] if not listeners
		self.eventListeners[eventName] = [listeners] if typeof listeners is \function
		self.eventListeners[eventName].push callback
		return {
			eventName: eventName
			callback: callback
			cb: real_cb
			off: ->
				#console.log "OFF", eventName, callback
				self.off eventName, callback
		}
	once: (eventName, callback) ->
		lala = @on eventName, callback, !->
			lala.cb ...
			process.nextTick ->
				#console.log "evt.off", @eventListeners[eventName].length, lala.cb
				lala.off!
				#console.log "evt.off.done", @eventListeners[eventName].length, lala.cb
	off: (eventName, callback) ->
		if not eventName
			@eventListeners = {}
		else
			if @eventListeners[eventName]
				if callback then
					#@eventListeners[eventName] = _.without @eventListeners[eventName], callback
					#console.log "callback", callback
					if ~(i = @eventListeners[eventName].indexOf callback)
						#console.log "cb", i, callback
						@eventListeners[eventName].splice i, 1
				else @eventListeners[eventName] = []

	# we're done now... return
	#return new Fsm name, options

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
