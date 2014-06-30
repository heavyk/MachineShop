require! \assert

Postal = require \postal
ToolShed = require './toolshed'
{ Debug, _, EventEmitter } = ToolShed
debug = Debug 'Fsm'

# inspired by ifandelse'a machina.js
#  https://github.com/ifandelse/machina.js
# and visionmedia's batch
#  https://github.com/visionmedia/batch

slice = [].slice

pipeline = Postal.channel \Machina
collective = {}

# for state recording, I think that this can be improved on quite a bit...
# I'd like to see a state progression like this [/state] -> saving -> saved -> [/state]

# add the ability to do:
# states:
# 	'node@>=0.11:uninitialized':
# 		onenter: ->
# I will need to wait for precalculated derivatives are done to do this, otherwise I'd have to call Semver.satisfies for every state (not cool!)


# originally this was based off of
# https://github.com/ifandelse/machina.js
# v0.3.2

# TODO: there will be problems using the 'off' function and the 'on' function can be optimized as well
# TODO: all functions need to obey the up and coming Da_Funk formula (bootsie: yer basic func formula)

class Fsm
	(name, options) ->
		# if typeof id is \string
		# 	name += "(#id)"
		# else options = id

		args1 = slice.call &, 1
		do
			uniq = Math.random!toString 32 .substr 2
			if typeof name is \string
				name += '.fsm.'+uniq
			else
				options = name
				name = 'fsm.'+uniq
		while collective[name]

		@debug = Debug name

		# init objects here... they can't be a part of the prototype...
		@_tasks = {}
		if typeof options is \object
			ToolShed.extend @, options
		unless @eventListeners
			@eventListeners = {}
		unless @eventQueue
			@eventQueue = []
		unless @namespace
			@namespace = name
		unless @states
			throw new Error "really, a stateless state machine (#{@namespace})???"
			@states = {}
		if typeof @initialState is \undefined
			@initialState = 'uninitialized'

		if (t = typeof @initialize) isnt \undefined => switch t
		| \function =>
			@initialize.apply @, args1
		| \object =>
			if Array.isArray @initialize
				for fn in @initialize
					if typeof fn is \function
						fn.apply @, args1
			else
				for key, fn of @initialize
					if typeof fn is \function
						fn.apply @, args1

		collective[name] = @
		pipeline.publish \Fsm:added, {id: name}
		if not @state and @initialState isnt false
			@debug "fsm transition initialState: #{@initialState}"
			@transition @initialState
		else @debug "waiting to transition #{@initialState}"

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
				# @deferUntilNextHandler cb
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
		if typeof (estate = states[@state].onerror) is \function
			estate.call @, err
		else if @eventListeners.error
			@emit \error err
		if _machina
			_machina.emit \Fsm:error @, err.stack or (err+'')
	exec: (cmd) ~>
		args = slice.call &, 0
		execd = 0

		@debug "exec: #cmd in #{@state}"
		if not @inExitHandler and state = @state
			states = @states
			handler = cmd

			do_exec = (fn, handler, path) !~>
				args1 = args.slice 1
				emit_obj = {
					cmd, handler, path
					args: args1
				}
				@emit.call @, \executing, emit_obj
				ret = fn.apply @, if handler is \* => args else args1
				@debug "exec(%s) called:ret (%s)", handler, if typeof ret is \object => \object else if typeof ret is \string and ret.length > 100 => (ret.substr 0, 97)+' ...' else ret
				emit_obj.ret = ret
				@emit.call @, \executed, emit_obj
				@emit.call @, "executed:#handler", emit_obj
				@processQueue \next-exec
				execd++
			if typeof (fn = states[state][handler]) is \string
				handler = fn
			if typeof (fn = states[state].'*') is \function
				do_exec fn, '*', "/states/#{state}/#{handler}"
			# else if (p = @processes) and typeof (fn = p[handler]) is \function
			# 	path = "/processes/#{handler}"
			# 	_fn = fn
			# 	fn = ->
			# 		task = @task "process:#handler"
			# 		task.start _fn
			# 		task
			@debug "handler #handler"
			if (p = @cmds) and typeof (fn = p[handler]) is \function
				do_exec fn, handler, "/cmds/#{handler}"
			if typeof (fn = states[state][handler]) is \function
				do_exec fn, handler, "/states/#{state}/#{handler}"

		if execd is 0
			@debug "exec: '#cmd' next transition (in state:#{@state}"
			obj = {
				type: \next-transition
				cmd: cmd
				args: args
			}
			@eventQueue.push obj
	execSoon: !~>
		a = &; process.nextTick ~> @exec.apply @, a
	transitionSoon: !~>
		a = &; process.nextTick ~> @transition.apply @, a
	transition: (newState) !->
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
				# process.nextTick ~>
				if @states[newState].onenter
					@states[newState].onenter.apply @, args1
				# if @targetReplayState is newState then @processQueue \next-transition
				if oldState is @initialState and not @_initialized
					@debug "initialzed! in %s", newState
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
			(item) ~> item.type is \next-transition
		else if type is \deferred
			(item, i) ~> item.type is \deferred and ((item.untilState and item.untilState is @state) or (item.notState and item.notState isnt @state))
		else
			(item) ~> item.type is \next-exec
		len_before = @eventQueue.length
		toProcess = _.filter @eventQueue, filterFn

		if toProcess.length
			@debug "processQueue:#type(#{toProcess.length})"
		_.each toProcess, !(item) ~>
			if filterFn item, i
				fn = if item.type is \deferred => item.cb else @exec
				fn.apply @, item.args
				i = @eventQueue.indexOf item
				@eventQueue.splice i, 1
	clearQueue: (type, name) !->
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
	process: (name) ->
		args = &
		task = @task "processs:#name"
		task.start (task) ~>
			# @processes[name].call @, [task] ++ args
			@processes[name].call @, task

	task: (scope, concurrency, name, cb) ->
		_name = 'random task #9'
		_concurrency = Infinity
		fsm = this
		self = this
		switch typeof scope
		| \function =>
			cb = scope
		| \string =>
			_name = scope
			cb = concurrency
		| \number =>
			cb = name
			name = concurrency
			concurrency = scope
		| \object =>
			self = scope

		switch typeof concurrency
		| \string =>
			_name = concurrency
			cb = name
		| \number =>
			_concurrency = concurrency

		if typeof name is \string
			_name = name

		task = new EventEmitter
		task.name = name = _name
		@debug "new task '%s'", _name
		task.scope = self
		task.i = 0
		task.running = 0
		task.complete = 0
		task.concurrency = concurrency = _concurrency
		task.results = []
		task.msgs = []
		task.chokes = []
		task.fns = []
		task.wait = ->
			i = task.fns.length
			if task.chokes[i - 1] isnt i
				fsm.debug "task[%s][%d]: choke", name, i
				task.chokes.push i
			return task
		task.choke = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			i = task.fns.length
			fsm.debug "task[%s][%d]: choke", name, i
			task.chokes.push i
			task.fns.push fn
			task.msgs.push txt
			unless task._paused => task.next!
			return task
		task.push = (txt, fn) ->
			if typeof txt is \function
				fn = txt
				txt = null
			i = task.fns.length
			fsm.debug "task[%s][%d]: push - %s", name, i, txt
			task.fns.push fn
			task.msgs.push txt
			unless task._paused => task.next!
			return task
		task.end = (cb) ->
			#TODO: when starting, save the task list into a nice little queue to callback at the end, then when calling start again it should be executing
			fsm.debug "task[%s][*]: end", name
			task._cb = cb
			if task.fns.length
				task.next!
			else
				task._paused = true
				if typeof cb is \function
					cb.call scope, null, task.results, name
			return task
		task.start = (cb) ->
			fsm.debug "task[%s]: start", name
			if typeof (_cb = task._cb) is \function
				_task = self.task task.scope task.concurrency, task.name
				_cb.call this, _task
				return _task


			if typeof cb is \function
				task._cb = cb
				process.nextTick ->
					cb.call scope, task
					if task.fns.length
						task.next!
			return task
		task.failure = (err) ->
			task._paused = true
			task.emit \failure err
		task.success = (res) ->
			task.emit \success res
		task.next = ->
			if task._paused => return
			i = task.i
			fn = task.fns[i]
			is_choke = if ~task.chokes.indexOf i then true else false
			if typeof fn is \undefined or task.running >= task.concurrency or (is_choke and task.running isnt 0)
				fsm.debug "task[%s][%d]: waiting.. not starting (running:%s/%s) choke:%s - %s", name, i, task.running, task.concurrency, is_choke, typeof fn
				return
			# fsm.debug "task[%s][%d]: running %s", name, i, is_choke
			start = new Date
			task.i++
			task.running++
			msg = task.msgs[i]

			fsm.debug "task[%s][%d]: running... (complete:%d/%d) (%s)", name, i, task.complete, task.fns.length, task.msgs[i]
			task.emit \running {
				msg: msg
				index: i
				running: task.running
				pending: pending: task.complete - task.fns.length
				total: task.fns.length
			}
			#try
			done_fn = (err, res) ->
				task.running--
				if err
					task._paused = true
					if typeof task._cb is \function
						task._cb.call task.scope, err
					task.emit \error, err
					return
				task.complete++
				end = new Date
				task.results[i] = res if res
				fsm.debug "task[%s][%d] done (complete:%d/%d running:%d) (%s)", name, i, task.complete, task.fns.length, task.running, task.msgs[i]
				task.emit \complete, {
					index: i
					value: res
					pending: task.complete - task.fns.length
					total: task.fns.length
					complete: task.complete
					msg: msg
					percent: task.complete / task.fns.length * 100 .|. 0
					start: start
					end: end
					duration: end - start
				}
				if (task.running + task.complete) < task.fns.length
					process.nextTick -> task.next!
				else if task.running is 0
					if typeof task._cb is \function
						fsm.debug "task[%s][*]: completed all tasks %d/%d (#{typeof task._cb})", name, task.complete, task.fns.length
						task._cb.call task.scope, null, task.results, name
					task.emit \end, null, task.results, name
					delete self._tasks[name]
			#catch e
			done_fn.dover = (times, error) ->
				times = 2 if typeof times is \undefined
				self.debug
				done_fn.dover = done_fn._dover times, error
				done_fn.dover!
			done_fn._dover = (times, error) ->
				return ->
					if times--
						self.debug "running... task remaining lives: #{times}"
						fn.call task.scope, done_fn
					else done_fn error || new Error "retry failed for task '#msg'"

			process.nextTick -> fn.call task.scope, done_fn
			if not is_choke and (task.running + task.complete) < task.fns.length then task.next!
		task.emit \task:added task
		if @_tasks[name]
			throw new Error "task '#name' already exists"

		if typeof cb is \function
			task.start cb


		if @tasks and typeof (fn = @tasks[name]) is \function
			t.start fn

		return @_tasks[name] = task

	# promt: (name, q) ->
	# 	@emit 'prompt', name, q
	# 	@emit 'prompt:'+name, q
	emitSoon: ~> a = &; process.nextTick ~> @emit.apply @, a
	emit: (eventName) ~>
		if @muteEvents then return
		args = &
		doEmit = ~>
			if @debug.online => switch eventName
			| \executing =>
				@debug "executing: (%s:%s)", @state, args.1.handler
			| \executed =>
				@debug "executed: (%s:%s)", @state, args.1.handler
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
				else _.each listeners, (callback) ~> callback.apply @, args1
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

	# we're done now... return
	#return new Fsm name, options

Empathy =
	derivative: (name, version) ->
		if version then Semver.satisfies version, @_derivatives[name]
		else @_derivatives[name]
	derivatives:
		'node-webkit': (cb) ->
			cb if typeof process is \object and typeof process.versions is \object then process.versions.'node-webkit' else void
		node: (cb) ->
			cb if typeof process is \object and typeof process.versions is \object then process.versions.node else void
		browser: (cb) ->
			cb if typeof window is \object and typeof window.navigator is \object then window.navigator.version else void
	'also|initialize': !->
		task = @task 'check derivatives'
		if typeof @_derivatives is \undefined
			@_derivatives = {}
			@__derivatives = []
		_.each @derivatives, (d, k) ~>
		# for k, d of @derivatives
			task.push "checking for #k" (done) ~>
				d (v) ~>
					@debug "d:ret:#k %s", v
					if v
						@_derivatives[k] = v
						@__derivatives.push k
						@debug "found derivative #k@#v"
					done void, v
		@on \derivative:remove ->
			@debug.todo "go through each one and remove the derivative version from the extended function"
		@on \derivative:add ->
			@debug.todo "go through each one and add the derivative versions to the extended function list if it's not already"
		@on \state:added (state) ->
			@debug.todo "calculate the derivatives"

		task.end ~>
			@emit \derivatives:calculated
			# event = (e)
			# OPTIMIZE!!! - this needs to find all the derivatives just once, then extend the functions
			# for now though, I'm just looping through them all every transition/cmd (slow)
			# though for derivative events, this will be pretty necessary
			transition = (e) ~>
				# _.each @_derivatives, (v, derivative) ~>
				for derivative in @__derivatives
					v = @_derivatives[derivative]
					if e.fromState and d = @states[e.fromState]."#derivative:onexit"
						d.apply @, e.args
					if d = @states[e.toState]."#derivative:onenter"
						d.apply @, e.args
			exec = (e) ~>
				# _.each @_derivatives, (v, derivative) ~>
				for derivative in @__derivatives
					v = @_derivatives[derivative]
					if (d = @states."#derivative:#{@state}") and dd = d[e.cmd]
						dd.apply @, e.args
					if (d = @cmds) and dd = d."#derivative:#{e.cmd}"
						dd.apply @, e.args

			# process.nextTick ~>
			@on \transition transition
			@on \executed exec
			# re-emit this to make sure to apply the derivatives in the uninitialized state
			if @state
				@debug "re-emit #{@initialState}"
				if @initialState isnt @state
					transition toState: @initialState, args: []
				transition fromState: @priorState, toState: @state, args: []

Fsm.Empathy = Empathy

export Empathy
export Fsm
export pipeline
export collective

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
