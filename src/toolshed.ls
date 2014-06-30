
Fs = require \fs
Path = require \path
Url = require \url
assert = require \assert
spawn = require \child_process .spawn
mkdirp = require \mkdirp
Rimraf = require \rimraf
printf = require \printf
EventEmitter = require \eventemitter3 .EventEmitter

# later this will be split into current / da_funk .. but for now use lodash
# _ = require \Current
_ = require \lodash
nw_version = if process.versions => process.versions.'node-webkit' else void
v8_version = (if nw_version then \nw else \node) + '_' + process.platform + '_' + process.arch + '_' + if process.versions => process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/).0 + '-' + process.versions.modules else if typeof window is \object => \browser else \unknown
HOME_DIR = if process.platform is \win32 then process.env.USERPROFILE else process.env.HOME
v8_mode = \Release

# maybe have a look at this:
# https://github.com/bjouhier/galaxy
# I want all functions to be called sync style
# needs to feel something like co
# https://github.com/jmar777/suspend

Debug = (namespace) ->
	#TODO: make this a verse/fsm which maintains the list of debugs
	unless path = Debug.namespaces[namespace]
		path = process.cwd!

	do_append_msg = (channel, prefix, postfix) ->
		_write = (msg, channel, prefix, postfix) !->
			if typeof postfix isnt \string
				postfix = '\n'
			else if postfix[*-1] isnt '\n'
				postfix += '\n'
			Fs.appendFileSync path, (prefix + msg + postfix)

		if typeof channel is \function
			write = channel
			channel = \debug
			prefix = ''
		if typeof prefix is \function
			write = prefix
			prefix = ''
		if typeof postfix is \function
			write = postfix

		if typeof write isnt \function
			write = _write
		else if typeof postfix isnt \string
			postfix = ''

		return !->
			msg = printf ...
			# TODO: make this a stream
			write msg, channel, prefix, postfix, _write
			if @emit => @emit if channel => "debug:#channel" else \debug, {message: msg}


	if HOME_DIR and not process.env.DEBUG
		#path = Path.join path, 'debug.log'
		debug = do_append_msg \debug, "[DEBUG] #{namespace}: "
		debug.warn = do_append_msg \warn, "[WARN] #{namespace}: "
		debug.info = do_append_msg \info, "[INFO] #{namespace}: "
		debug.todo = do_append_msg \todo, "[TODO] #{namespace}: ", (msg, channel, prefix, postfix, write) !->
			try
				throw new Error "TODO: error"
			catch e
				stack = e.stack.split '\n'
				postfix += '\n'
				i = 3
				if ~(stack[i].indexOf 'do_exec')
					i += 1
				if ~(s = stack[i].indexOf 'prototype.exec')
					i += 1
				postfix += "\n    at #{stack[i].trim!}"
			write msg, channel, prefix, postfix
		debug.error = do_append_msg \error, "[ERROR] #{namespace}: ", (msg, channel, prefix, postfix, _write) ->
			if not process.env.DEBUG_NO_DEBUGGER => debugger
			_write ...
		debug.log = do_append_msg \log, "[LOG] #{namespace}: "
		start = ->
			# path := Path.join HOME_DIR, '.ToolShed', "#{namespace}-debug.log"
			path := Path.join HOME_DIR, '.ToolShed', "debug.log"
			mkdirp Path.dirname(path), (err) ->
				Fs.writeFileSync path, ""
				debug "Debug(#namespace) starting at '#path'"

		debug.namespace = ~
			-> namespace
			(v) ->
				start!
				namespace := v
		debug.assert = assert

		start!
	else
		# EXPLANATION: the reason for the double function is because of invalid invocation feature of console.log
		if console.debug
			debug = do_append_msg \debug, " [DEBUG - #{namespace}]: ", (msg, channel, prefix, postfix) -> console.debug (msg + postfix)
		else
			debug = do_append_msg \debug, " [DEBUG - #{namespace}]: ", (msg, channel, prefix, postfix) -> console.log (prefix + msg + postfix)
		debug.todo = do_append_msg \todo, " [INFO - #{namespace}]: ", (msg, channel, prefix, postfix) -> console.info ('[TODO] ' + msg + postfix)
		debug.warn = do_append_msg \warn, " [WARN #{namespace}]: ", (msg, channel, prefix, postfix) -> console.warn (msg + postfix)
		debug.info = do_append_msg \info, " [INFO #{namespace}]: ", (msg, channel, prefix, postfix) -> console.info (msg + postfix)
		debug.error = do_append_msg \error, " [ERROR #{namespace}]: ", (msg, channel, prefix, postfix) -> console.error (msg + postfix); debugger
		debug.log = do_append_msg \log, " [LOG #{namespace}]: ", (msg, channel, prefix, postfix) -> console.log (msg + postfix)
		debug.assert = assert
		debug.namespace = ~
			-> namespace
			(v) -> namespace := v
	return debug
Debug.namespaces = {}
#TODO: implement colors
Debug.colors = true
debug = Debug 'ToolShed'

# XXX - I REALLY want to integrate fiber support into sencillo
#     - it should be transparent to the programmer whether it's a sync func or not
# in the case of node-webkit or node-0.11.3+, it should use yield
# in the case of node normal it should use fibers or gnode style of yield (whichever is faster)
Fiber = ->
Future = ->
	#TODO: use yield funcs to simulate a future (a la fibers...)

class Environment
	_bp:
		idea: \Environment


	(env) ->
		if typeof env isnt \object
			env = process.env

		@nw_version = if process.versions => process.versions.'node-webkit' else void
		@v8_version = (if nw_version then \nw else \node) + '_' + process.platform + '_' + process.arch + '_' + if process.versions => process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/).0 + '-' + process.versions.modules else if typeof window is \object => \browser else \unknown
		@HOME_DIR = if process.platform is \win32 then process.env.USERPROFILE else process.env.HOME

		@env = env



scan = (str) ->
	re = /(?:(\S*"[^"]+")|(\S*'[^']+')|(\S+))/g
	toks = []
	tok = void
	m = void
	braceExpand = require 'minimatch' .braceExpand
	while m = re.exec str
		tok = m.0
		tok = braceExpand tok, {nonegate: true}
		toks = toks.concat tok
	toks

parse = (str) ->
	toks = scan str
	cmds = []
	cmd = {
		env: {}
		argv: []
	}
	for tok, i in toks
		if '|' is tok then continue
		if tok.indexOf('=') > 0
			part = tok.split '='
			cmd.env[part.shift!] = unquote part.join '='
		else
			cmd.name = tok
			while toks[i + 1] and toks[i + 1] isnt '|'
				cmd.argv.push toks[++i]
			cmds.push cmd
			cmd = {
				env: {}
				argv: []
			}
	cmds

rm = (dir, cb) ->
	if typeof cb is \function
		Rimraf dir, cb
	else
		# fixme
		Rimraf dir, ->

isDirectory = (path) ->
	debug "isDirectory %s", path
	try
		s = stat path
		return s.isDirectory!
	catch err
		return false

unquote = (str) ->
	str.replace /^"|"$/g, '' .replace /^'|'$/g, '' .replace /\n/g, '\n'

isQuoted = (str) -> '"' is str.0 or '\'' is str.0

stripEscapeCodes = (str) -> str.replace /\033\[[^m]*m/g, ''

# all these should be livescript expands
mkdir = (path, cb) ->
	debug "mkdir %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	if typeof cb is \function
		mkdirp path, cb
	else if Fiber.current
		future = new Future
		mkdirp path, (err, d) ->
			future.return err or d
		future.wait!
	else mkdirp.sync path

exists = (path, cb) ->
	debug "exists %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	if typeof cb is \function
		Fs.exists path, cb
	else if Fiber.current
		future = new Future
		Fs.exists path, (exists) ->
			future.return exists
		v = future.wait!
		return v
	else Fs.existsSync path

stat = (path, cb) ->
	debug "stat %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	if typeof cb is \function
		Fs.stat path, cb
	else if Fiber.current
		future = new Future
		Fs.stat path, (err, st) ->
			future.return err or st
		future.wait!
	else Fs.statSync path

readdir = (path, cb) ->
	debug "readdir(%s) %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	if typeof cb is \function
		Fs.readdir path, cb
	else if Fiber.current
		future = new Future
		Fs.readdir path, (err, files) ->
			unless err
				_.each files, (file, i) ->
					f = {}
					Object.defineProperty f, \st get: -> stat file
					Object.defineProperty f, \toString get: -> file
					#files.splice i, 1, f
			future.return err or files
		future.wait!
	else
		try
			files = Fs.readdirSync path
			_.each files, (file, i) ->
				f = {}
				Object.defineProperty f, \st get: -> stat file
				Object.defineProperty f, \toString get: -> file
				#files.splice i, 1, f
		catch err then throw err
		files

readFile = (path, enc, cb) ->
	debug "readFile %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	#TODO: add in support for extra parameters
	if typeof enc is \function
		cb = enc
		enc = 'utf-8'
	if typeof cb is \function
		Fs.readFile path, enc, cb
	else if Fiber.current
		future = new Future
		Fs.readFile path, enc, (err, st) ->
			future.return err or st
		future.wait!
	else Fs.readFileSync path, enc

writeFile = (path, data, cb) ->
	debug "writeFile %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	#TODO: add in support for extra parameters
	if typeof cb is \function
		Fs.writeFile path, data, cb
	else if Fiber.current
		future = new Future
		Fs.writeFile path, data, (err, st) ->
			future.return err or st
		future.wait!
	else Fs.writeFileSync path, data

# I really wanna make this much more like procstreams... look into it!
exec = (cmd, opts, cb) ->
	if typeof opts is \function
		cb = opts

	if typeof opts isnt \object
		opts = {stdio: \pipe}
	# unless opts.stdio
	# 	opts.stdio = \silent

	debug "exec '%s'", cmd
	if debug.deep
		var deep_err
		try
			throw new Error "exec '#cmd' #{DaFunk.stringify opts} failed"
		catch err
			deep_err := err

	if opts.stdio is \silent
		silent = true
		opts.stdio = \pipe

	opts.stdio = \pipe unless opts.stdio is \inherit
	opts.env = process.env if not opts.env
	cmds = cmd.split ' '
	# console.log "spawn: ", cmd, opts
	p = spawn cmds.0, cmds.slice(1), opts
	# console.log "p:", p
	stdout = ''
	stderr = ''
	if p.stdout or true
		p.stdout.on \data (data) ->
			stdout += data+''
			process.stdout.write data unless silent
	if p.stderr
		p.stderr.on \data (data) ->
			stderr += data+''
			process.stderr.write data unless silent
	p.on \error (err) ->
		opts.env = "process.env" if opts.env is process.env
		debug "exec '#cmd' failed %s", DaFunk.stringify opts
		cb err
	p.on \close (code) ->
		if code
			debug "#cmd -> #code, stdout: '#stdout' stderr: '#stderr'"
			if debug.deep
				debug err.stack
				err = deep_err
			else
				err = new Error "exec '#cmd' exited with code #code"
			err.code = code
		cb err, stdout, stderr
	return p

searchDownwardFor = (file, dir, cb) ->
	if typeof dir is \function
		cb = dir
		dir = process.cwd!
	test_dir = (dir) ->
		path = Path.join dir, file
		debug "testing %s", path
		Fs.stat path, (err, st) ->
			if err
				if err.code is \ENOENT
					dir := Path.resolve dir, '..'
					if dir is Path.sep
						cb err
					else test_dir dir
			else if st.isFile!
				cb null, path
			else console.log "....", st
	test_dir dir

recursive_hardlink = (path, into, cb) ->
	debug "recursive_hardlink %s -> %s", path, into, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	rh = (done) ->
		Fs.readdir path, (err, files) ->
			if err => return cb err
	if typeof cb is \function
		Fs.readdir path, cb
	else if Fiber.current
		future = new Future
		Fs.readdir path, (err, files) ->
			unless err
				_.each files, (file, i) ->
					f = {}
					Object.defineProperty f, \st get: -> stat file
					Object.defineProperty f, \toString get: -> file
					#files.splice i, 1, f
			future.return err or files
		future.wait!
	else
		try
			files = Fs.readdirSync path
			_.each files, (file, i) ->
				f = {}
				Object.defineProperty f, \st get: -> stat file
				Object.defineProperty f, \toString get: -> file
				#files.splice i, 1, f
		catch err then throw err
		files

debug_fn = (namespace, cb, not_fn) ->
	if typeof namespace is \function
		cb = not_fn
		cb = namespace
		namespace = void
	return ->
		if typeof cb is \function
			if not namespace or (typeof namespace is \string and ~DEBUG.indexOf namespace) or (namespace instanceof RegEx and namespace.exec DEBUG)
				debugger
			cb ...
		else if not not_fn
			throw new Error "can't debug a function this not really a function"


# BIKESHED: I really would rather obj as the first param: (obj, path, ...)
# OPTIMIZE! - have a look at using indexOf and substr instead of path.split - I think that will be the fastest.
# these will be the typed, signatures:
# get_obj_path = (Array path, Function^Object obj) ->
# get_obj_path = (String path, Function^Object obj, String split = '/') ->
get_obj_path = (path, obj, split) ->
	if typeof path is \string
		if typeof split is \undefined => split = '.' # TODO: this should really be: '/'
		if typeof split isnt \string => throw new Error "arg{3:split} is supposed to be a string"
		paths = path.split split
	else if Array.isArray path
		paths = path # .slice 0 # - slice isn't necessary because we don't modify the array
	else
		throw new Error "arg{1:path} is supposed to be of type String or Array"
	if typeof obj isnt \function and typeof obj isnt \object => throw new Error "arg{2:obj} is supposed to be of type Object or Function"
	i = 0
	_obj = obj
	while i < paths.length and _obj
		_obj = _obj[paths[i++]]
	_obj

# TODO: document these functions speed using jsperf and then put the urls in here for quick reference (also keep them locally in origin/*.jsperf.ls)
# example setup:
# paths = []
# obj = {}
# for i to 100
# 	p = []
# 	for d to (Math.ceil Math.random! * 5)
# 		p.push Math.random!toString 32 .substr 2
# 	paths.push (pp = p.join '.')
# 	ToolShed.set_obj_path pp, obj
# this is most likely the slowest
# get_in_obj2 = (obj, str) -> (str.split '/').reduce ((o, x) -> o[x]), obj
# this is now possible:
#   ToolShed.set_obj_path "property.{DaFunk,ToolShed}", my_obj, require \MachineShop
# TODO: add types to LiveScript:
# set_obj_path = (Array path, Function^Object obj, !undefined val, String subsplit = ',') ->
# set_obj_path = (String path, Function^Object obj, !undefined val, String split = '/', String subsplit = ',') ->
# BIKESHED: I really would rather obj as the first param: (obj, path, val, ...)
set_obj_path = (path, obj, val, split, subsplit) ->
	if typeof path is \string
		if typeof split is \undefined => split = '.' # TODO: this should really be: '/'
		if typeof split isnt \string => throw new Error "arg{4:split} is supposed to be a string"
		paths = path.split '.'
	else if Array.isArray path
		subsplit = split
		paths = path.slice 0
	else throw new Error "arg{1:path} is supposed to be of type String or Array"
	if typeof obj isnt \function and typeof obj isnt \object => throw new Error "arg{2:obj} is supposed to be of type Object or Function"
	if typeof val is \undefined => throw new Error "arg{3:val} cannot be undefined"
	if typeof subsplit is \undefined => subsplit = ',' # TODO: this potentially could be: '|'
	if typeof subsplit isnt \string => throw new Error "arg{5:subsplit} is supposed to be a string"
	if paths.length
		subobj = obj
		while paths.length # > 1
			path = paths.shift!trim!
			if ~(i = path.indexOf '{') and ~(ii = path.lastIndexOf '}')
				subpaths = path.substr i+1, ii-1
				for p in subpaths.split subsplit
					# this is largely untested, though I know that it 'works' ... lol, write tests dude!
					# debugger
					p = (path.substr 0, i) + (p.trim!) + (path.substr ii+1)
					pp = [p] ++ paths
					set_obj_path pp, obj, get_obj_path pp, val
				return

			if paths.length is 0
				subobj[path] = val
				subobj[path+'_____________dynset'] = true
				obj._dynset = true
			else
				_subobj = subobj[path]
				if typeof _subobj is \undefined
					debugger
					_subobj = {}
					subobj[path] = _subobj
				subobj = _subobj
	else
		# TODO: add a @debug.fixme "you called set_obj_path without a resolvable path"
		debug.warn "could not find a path to set to. this is probably not intended"


export _
export EventEmitter
export nw_version
export v8_version
export HOME_DIR
export Environment
export v8_mode
export Debug
export Future
export parse
export rm
export isDirectory
export unquote
export isQuoted
export stripEscapeCodes
export mkdir
export exists
export stat
export readdir
export readFile
export writeFile
export exec
export searchDownwardFor
export recursive_hardlink
export debug_fn
export get_obj_path
export set_obj_path