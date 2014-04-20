assert = require \assert
Semver = require \semver
ToolShed = require './toolshed'
{ Debug, _, EventEmitter } = ToolShed
debug = Debug 'Fsm'

# inspired by ifandelse'a machina.js
#  https://github.com/ifandelse/machina.js
# and visionmedia's batch
#  https://github.com/visionmedia/batch

slice = [].slice
# TODO: we can really do this better... I'm sure. make this a part of Machina

makeFsmNamespace: (->
	machinaCount = 0
	-> 'fsm.' + machinaCount++
)!

# later, this will become a blueprint for multi-client use
# the name of this is a reference to a gift I received as a child from a girl named Jenny
# TODO: require the blueprint directly
Fabuloso =
	derivitave: (name, version) ->
		if version then Semver.version version, @_derivitaves[name]
		else @_derivitaves[name]
	derivitaves:
		'node-webkit': (cb) ->
			cb if typeof process is \object and typeof process.versions is \object then process.versions.'node-webkit' else void
		node: (cb) ->
			cb if typeof process is \object and typeof process.versions is \object then process.versions.node else void
		browser: (cb) ->
			cb if typeof window.navigator is \object then window.navigator.version else void
		# TODO: move this over to PublicDB
		# TODO: move over the jive localarchive stuff to publicdb
		# arango: (cb) ->
		# 	#TODO: get the config values from somewhere
		# 	return cb!
		# 	db = arango.Connection
		# 	db.admin.version false, (err, res) ->
		# 		console.log "arango", &
		# 		if err then cb 1
		# 		else if typeof cb is \function then cb res.version
	'extend.initialize': !->
		if typeof @_derivitaves is \undefined
			@_derivitaves = {}
		task = @task 'check derivitaves'
		_.each @derivitaves, (d, k) ->
			task.push "checking for #k" (done) ->
				self = @
				d (v) ->
					if v
						self._derivitaves[k] = v
						self.debug "found derivitave #k@#v"
					done void, v

		task.end ->
			# re-emit this to make sure to apply the derivitaves in the uninitialized state
			if @state
				@debug "re-emit #{@initialState}"
				@emit \transition, toState: @initialState



# https://github.com/ifandelse/machina.js
# v0.3.2
# modified eventListeners to accept a function, but convert to an array if more than one is found
# TODO: this should be improved...
#   there will be problems using the 'off' function and the 'on' function can be optimized as well
# TODO: add fsm logging capability (and show this log inside of verse)

export class Fsm
	total_deferred = 0
	(name, options) ->
		if typeof name is \string
			name += '.fsm.'+Math.random!toString 32 .substr 2
		else
			options = name
			name = makeFsmNamespace!
		@debug = Debug name
		@debug "new Fsm!"
		if _machina
			_machina.emit \new:Fsm, @

		# init objects here... they can't be a part of the prototype...
		@tasks = {}
		if typeof options is \object
			ToolShed.extend @, options
		unless @eventListeners
			@eventListeners = {}
		unless @eventQueue
			@eventQueue = []
		unless @states
			console.log "@", @
			throw new Error "really, a stateless state machine???"
			@states = {}
		unless @namespace
			@namespace = name
		if typeof @initialState is \undefined
			@initialState = 'uninitialized'

		# console.log "states:", @states, options?states, options

		# process.nextTick ~>
		switch typeof @initialize
		| \function =>
			@initialize.call @, options
		| \object =>
			if Array.isArray @initialize
				for fn in @initialize
					if typeof fn is \function
						fn.call @, options
			else
				for key, fn of @initialize
					if typeof fn is \function
						fn.call @, options

		#machina.emit \new:Fsm, @
		@debug "fsm state #{@state}"
		if not @state
			@transition @initialState

	muteEvents: false
	concurrency: Infinity
	_initialized: false
	once_initialized: (cb) ~>
		assert this instanceof Fsm
		@debug "once_initialized... %s", @_initialized
		if typeof cb is \function
			if @_initialized
				cb.call @
			else
				@eventQueue.push {
					type: \deferred
					notState: @initialState
					cb: cb
				}
		@_initialized
	reset: ~>
		@state = void
		@initialize.call @ if typeof @initialize is \function
		@transitionSoon @initialState if @initialState
	error: (err) ~>
		states = @states
		if estate = states[@state].onerror
			@states[@state].onerror.call @
		else
			# commit to the debug log
			console.error err.stack or (err+'')
	exec: (cmd) ~>
		@debug "exec: (%s:%s)", @state, cmd
		if not @inExitHandler
			states = @states
			state = @state
			args = slice.call &, 0
			args1 = args.slice 1
			handlerName = void
			handler = void
			catchAll = void
			ret = void
			@currentActionArgs = args
			if state and (states[state][cmd] or states[state].'*' or @'*') or @cmds and typeof (handler = @cmds[cmd]) is \function
				if state and (handlerName = if states[state][cmd] then cmd else '*') and handler = states[state][handlerName]
					@_currentAction = state + '.' + handlerName
				else if @cmds and typeof (handler = @cmds[cmd]) is \function
					# TODO: this is pretty unoptimized. go ahead and improve this. you will notice that above, I'm already saving the handler
					@_currentAction = handlerName = cmd
					# neither am I 100 % sure why I'm saving the _currentAction ... I never use it
				else
					handler = @'*'
					@_currentAction = '*'
				@emit.call @, \executing, {
					type: cmd
					args: args1
				}
				# TODO: check if this works and/or is faster:
				# @debug.optimize "chech to see if calling toString directly is faster than a concat with '' ... see below:"
				#if (handler+'') is '[object String]'
				if (Object::toString.call handler) is '[object String]'
					@debug "exec bullshit:transition (%s)", handler
					@debug.todo "I think this is loke a forwarder... look into it and make sure. lala: mycmd: 'lala.lala' should transition to 'lala.lalai or it should call lala: lala: -> console.log 'hello world'"
					@debug.todo "wait, this might mean that an exec that is lala: lala: 'mmm' -> transition \\mmm"
					@transition handler
				else
					ret = handler.apply @, if handlerName is \* then args else args1
					@debug "exec called:ret (%s)", ret
				@emit.call @, \executed, {
					type: cmd
					args: args1
					ret: ret
				}
				@_priorAction = @_currentAction
				@_currentAction = ''
				@processQueue \next-exec
			else
				@debug "exec: next transition"
				# console.log "next transition", args
				obj = {
					type: \next-transition
					cmd: cmd
					args: args.slice 0 # why are we slicing here?
				}
				@eventQueue.push obj
			@currentActionArgs = void
			return ret
	execSoon: ~> a = &; process.nextTick ~> @exec.apply @, a
	transitionSoon: ~> a = &; process.nextTick ~> @transition.apply @, a
	transition: (newState) ->
		if typeof newState isnt \string
			newState = newState+''
		if @inTransition
			return @transitionSoon ...
		@debug "fsm: transition %s -> %s", @state, newState
		if not @inExitHandler and newState isnt @state
			oldState = void
			args1 = slice.call(&, 1)
			if @states[newState]
				@inTransition = newState
				@targetReplayState = newState
				@priorState = @state
				@state = newState
				if oldState = @priorState
					if @states[oldState] and @states[oldState].onexit
						@inExitHandler = true
						@states[oldState].onexit.apply @, args1
						@inExitHandler = false
				if @states[newState].onenter
					@states[newState].onenter.apply @, args1
				if oldState is @initialState and not @_initialized
					@debug "%s initialzed! in %s", @namespace, newState
					@_initialized = true
				@debug "fsm: post-transition %s -> %s", oldState, newState
				@emit.apply @, ["state:#newState"] ++ args1
				@emit.call @, \transition, {
					fromState: oldState
					toState: newState
					args: args = args1
				}
				@processQueue.call this, \next-transition
				@processQueue.call this, \deferred
				@inTransition = null
			else
				@debug "attempted to transition to an invalid state: %s", newState
				#TODO: when the state machine is virtualized, ask the user to add the state
				@emit.call @, \invalid-state, {
					@state
					attemptedState: newState
					args: args1
				}
	processQueue: (type) !->
		filterFn = if type is \next-transition
			(item) ~> item.type is \next-transition and typeof @states[@state][item.cmd] isnt \undefined
		else if type is \deferred
			(item, i) ~> item.type is \deferred and ((item.untilState and item.untilState is @state) or (item.notState and item.notState isnt @state))
		else
			(item) ~> item.type is \next-exec
		len_before = @eventQueue.length
		toProcess = _.filter @eventQueue, filterFn

		_.each toProcess, !(item) ~>
			if filterFn item, i
				fn = if item.type is \deferred => item.cb else @exec
				fn.apply @, item.args
				i = @eventQueue.indexOf item
				@eventQueue.splice i, 1
	clearQueue: (type, name) ->
		if not type
			@eventQueue = []
		else
			filter = void
			if type is \next-transition
				filter = (evnt) ~> evnt.type is \next-transition and if name then evnt.untilState is name else true
			else
				if type is \next-exec then filter = (evnt) ~> evnt.type is \next-exec
			@eventQueue = _.filter @eventQueue, filter
	until: (stateName, cb) ->
		args = slice.call &, 2
		if @state is stateName
			cb.apply @, args
		else
			queued = {
				type: \deferred
				untilState: stateName
				cb: cb
				args: args
			}
			@eventQueue.push queued
	deferUntilTransition: (stateName) ->
		if @currentActionArgs
			queued = {
				type: \next-transition
				untilState: stateName
				args: @currentActionArgs
			}
			@eventQueue.push queued
			@emit.call @, \deferred, {
				@state
				queuedArgs: queued
			}
	deferUntilNextHandler: ->
		if @currentActionArgs
			queued = {
				type: \next-transition
				args: @currentActionArgs
			}
			@eventQueue.push queued
			@emit.call @, \deferred, {
				@state
				queuedArgs: queued
			}
	task: (name) ->
		@debug "new task '%s'", name
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
			branch = self.task name
			branch.parent = self
			branch
		task.choke = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			self.debug "task(%s): choke %d", name, task.fns.length
			task.chokes.push task.fns.length
			task.fns.push fn
			task.msgs.push txt
			task.done = false
			if task.i
				task.next!
			task
		task.add = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			# self.debug "task(%s): add %d", name, task.fns.length
			i = task.fns.length
			task.fns.splice i, 0, fn
			task.msgs.splice i, 0, txt
			task.done = false
			task.next!
			task
		task.push = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			# self.debug "task(%s): push %d: %s", name, task.fns.length, txt
			i = task.fns.length
			task.fns.push fn
			task.msgs.push txt
			task.done = false
			if task.i isnt 0
				task.next!
			task
		task.end = (cb) ->
			self.debug "task(%s): end", name
			task.cb = cb
			#process.nextTick ->
			if task.fns.length
				# console.log "task: starting #{name} #{task.fns.length}"
				return task.next!
			else
				# console.log "task: nothing to do... #{name} #{task.fns.length}", cb
				task.done = true
				# self.inExitHandler = false
				return cb.call self, null, task.results, name
		task.next = ->
			# self.inExitHandler = true
			# console.log "next..."
			i = task.i
			fn = task.fns[i]
			is_choke = if ~task.chokes.indexOf i then true else false
			if typeof fn is \undefined or task.running >= task.concurrency or (is_choke and task.running isnt 0)
				if typeof task.parent is \function then task.parent.next!
				self.debug "task(%s): waiting \#%d (running:%s/%s) choke:%s - %s", name, i, task.running, task.concurrency, is_choke, typeof fn
				return
			# self.debug "task(%s): running %d %s", name, i, is_choke
			start = new Date
			task.i++
			task.running++

			self.debug "task(%s): running... \#%s (complete:%d/%d) (%s)", name, i, task.complete, task.fns.length, task.msgs[i]
			task.emit \running {
				msg: task.msgs[i]
				index: i
				running: task.running
				pending: pending: task.complete - task.fns.length
				total: task.fns.length
			}
			#try
			fn.call self, (err, res) ->
				task.running--
				if err
					task.done = true
					if typeof task.cb is \function
						task.cb.call self, err
					task.emit \error, err
					return
				task.complete++
				end = new Date
				task.results[i] = res if res
				self.debug "task(%s): done \#%s (complete:%d/%d running:%d) (%s)", name, i, task.complete, task.fns.length, task.running, task.msgs[i]
				task.emit \complete, {
					index: i
					value: res
					pending: task.complete - task.fns.length
					total: task.fns.length
					complete: task.complete
					msg: task.msgs[i]
					percent: task.complete / task.fns.length * 100 .|. 0
					start: start
					end: end
					duration: end - start
				}
				# self.debug "task(%s): deciding... %d/%d `%s`", name, task.complete, task.fns.length, typeof task.cb
				if (task.running + task.complete) < task.fns.length
					process.nextTick -> task.next!
				else if task.running is 0
					if typeof task.cb is \function
						self.debug "task(%s): completed all tasks %d/%d", name, task.complete, task.fns.length
						# console.log "task: #{task.name} completed all tasks..."
						task.cb.call self, null, task.results, name
					task.emit \end, null, task.results, name
					delete self.tasks[name]
			#catch e
			if not is_choke and (task.running + task.complete) < task.fns.length then task.next!
		task.emit \task:new task
		if @tasks[name]
			throw new Error "task already exists"
		return @tasks[name] = task

	# promt: (name, q) ->
	# 	@emit 'prompt', name, q
	# 	@emit 'prompt:'+name, q
	emitSoon: ~> a = &; process.nextTick ~> @emit.apply @, a
	emit: (eventName) ~>
		if @muteEvents then return
		args = &
		doEmit = ~>
			switch eventName
			| \executing =>
				@debug "executing: (%s:%s)", @state, args.1?type
			| \executed =>
				@debug "executed: (%s:%s)", @state, args.1?type
			| \invalid-state =>
				@debug.error "bad transition: (%s !-> %s)", args.1.state, args.1.attemptedState
			| \transition =>
				@debug "transition: (%s -> %s)", args.1.fromState, args.1.toState
			| otherwise =>
				@debug "emit: (%s): num args %s", eventName, args.length - 1
			if listeners = @eventListeners.'*'
				if typeof listeners is \function then listeners.apply @, args
				else _.each @eventListeners.'*', ((callback) -> callback.apply @, args), @
			if listeners = @eventListeners[eventName]
				args1 = slice.call args, 1
				if typeof listeners is \function then listeners.apply @, args1
				else
					# console.log "listeners", listeners.length
					_.each listeners, (callback) ~> callback.apply @, args1
		doEmit.call @
		return @
	on: (eventName, real_cb, callback) ~>
		if typeof callback isnt \function
			callback = real_cb
			real_cb = void
		listeners = @eventListeners[eventName]
		# this is a hackedy hack to make sure we're not modifying the prototype
		if @eventListeners is @__proto__.eventListeners
			@eventListeners = _.cloneDeep @eventListeners
		@eventListeners[eventName] = [] if not listeners
		@eventListeners[eventName] = [listeners] if typeof listeners is \function
		@eventListeners[eventName].push callback
		if eventName.substr(0, 6) is "state:" and @state is eventName.substr 6
			process.nextTick ~>
				callback.call @
		return {
			eventName: eventName
			callback: callback
			cb: real_cb
			off: ~> @off eventName, callback
		}
	once: (eventName, callback) ~>
		evt = @on eventName, callback, !~>
			evt.cb ...
			process.nextTick ~>
				evt.off eventName, callback
	off: (eventName, callback) ->
		if not eventName
			@eventListeners = {}
		else
			if @eventListeners[eventName]
				if callback then
					if ~(i = @eventListeners[eventName].indexOf callback)
						@eventListeners[eventName].splice i, 1
				else @eventListeners[eventName] = []


# later, in the future, integrate this with [node] webworker threads
# to allow for multiple threads, duh
class Machina extends Fsm
	fsms: []
	(name) ->
		console.log "yay! we are a new Machina"
		super "Machina"
		ToolShed.extend @, Fabuloso

	eventListeners:
		newfsm: (fsm) ->
			@fsms.push fsm

	states:
		uninitialized:
			onenter: ->
				@transition \ready

		ready:
			onenter: ->
				@debug "machina ready!"


_machina = new Machina
Object.defineProperty exports, "Machina",
	get: ->
		if not _machina
			_machina := new Machina
		return _machina

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

export Fabuloso
export Fsm
