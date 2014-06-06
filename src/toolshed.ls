
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

	if HOME_DIR and not process.env.DEBUG
		#path = Path.join path, 'debug.log'
		debug = !->
			msg = printf ...
			Fs.appendFileSync path, "[DEBUG] #{namespace}: #msg\n"
		debug.warn = !->
			msg = printf ...
			Fs.appendFileSync path, "[WARN] #{namespace}: #msg\n"
		debug.info = !->
			msg = printf ...
			Fs.appendFileSync path, "[INFO] #{namespace}: #msg\n"
		debug.todo = !->
			msg = printf ...
			Fs.appendFileSync path, "[TODO] #{namespace}: #msg\n"
		debug.error = !->
			msg = printf ...
			Fs.appendFileSync path, "[ERROR] #{namespace}: #msg\n"
		debug.log = !->
			msg = printf ...
			Fs.appendFileSync path, "[LOG] #{namespace}: #msg\n"
		start = ->
			# path := Path.join HOME_DIR, '.ToolShed', "#{namespace}-debug.log"
			path := Path.join HOME_DIR, '.ToolShed', "debug.log"
			mkdirp Path.dirname(path), (err) ->
				Fs.writeFileSync path, ""
				debug "starting..."

		debug.namespace = ~
			-> namespace
			(v) ->
				start!
				namespace := v
		debug.assert = assert

		start!
	else
		debug = !->
			msg = printf ...
			console.log " [DEBUG - #{namespace}]: #msg"
		debug.todo = !->
			msg = printf ...
			console.info " [INFO - #{namespace}]: [TODO] #msg"
		debug.warn = !->
			msg = printf ...
			console.warn " [WARN #{namespace}]: #msg"
		debug.info = !->
			msg = printf ...
			console.info " [INFO #{namespace}]: #msg"
		debug.error = !->
			msg = printf ...
			console.error " [ERROR #{namespace}]: #msg"
		debug.log = !->
			msg = printf ...
			console.log " [LOG #{namespace}]: #msg"
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

rimraf = (dir, cb) ->
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
		opts = {stdio: \inherit}
	opts.stdio = \inherit unless opts.stdio
	opts.env = process.env unless opts.env
	cmds = cmd.split ' '
	p = spawn cmds.0, cmds.slice(1), opts
	p.on \close (code) ->
		if code then cb new Error "exit code: "+code
		else cb code

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


export _
export EventEmitter
export nw_version
export v8_version
export HOME_DIR
export v8_mode
export Debug
export Future
export parse
export rimraf
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