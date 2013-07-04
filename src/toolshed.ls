
Fs = require \fs
Path = require \path
Url = require \url
spawn = require('child_process').spawn
_ = require \lodash
mkdirp = require 'mkdirp'
debug = (require 'debug') 'utils'

export nw_version = process.versions.'node-webkit'
export v8_version = (if nw_version then \nw else \node) + '_' + process.platform + '_' + process.arch + '_' + process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/).0
export v8_mode = \Release

# XXX - I REALLY want to integrate fiber support into sencillo
#     - it should be transparent to the programmer whether it's a sync func or not

if nw_version or true
	global.Fiber = (cb) ->
		return {
			run: -> cb!
		}
	global.Future = ->
		return {
			wait: -> throw new Error "Future.wait not implemented!"
			return: -> throw new Error "Future.return not implemented!"
		}
else
	global.Fiber = require \fibers
	global.Future = require \fibers/future

(<- Fiber

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

export parse = (str) ->
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

export isDirectory = (path) ->
	debug "isDirectory %s", path
	try
		s = stat path
		return s.isDirectory!
	catch err
		return false

export unquote = (str) ->
	str.replace /^"|"$/g, '' .replace /^'|'$/g, '' .replace /\n/g, '\n'

export isQuoted = (str) -> '"' is str.0 or '\'' is str.0

export stripEscapeCodes = (str) -> str.replace /\033\[[^m]*m/g, ''

# all these should be livescript expands
export mkdir = (path, cb) ->
	debug "mkdir %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	if typeof cb is \function
		mkdirp path, cb
	else if Fiber.current
		future = new Future
		mkdirp path, (err, d) ->
			future.return err or d
		future.wait!
	else mkdirp.sync path

export exists = (path, cb) ->
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

export stat = (path, cb) ->
	debug "stat %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	if typeof cb is \function
		Fs.stat path, cb
	else if Fiber.current
		future = new Future
		Fs.stat path, (err, st) ->
			future.return err or st
		future.wait!
	else Fs.statSync path

export readdir = (path, cb) ->
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

export readFile = (path, enc, cb) ->
	debug "readFile %s -> %s", path, if typeof cb is \function then 'callback' else if Fiber.current then \fiber else \sync
	#TODO: add in support for extra parameters
	#if typeof enc is \function
	#	cb = enc
	if typeof cb is \function
		Fs.readFile path, enc, cb
	else if Fiber.current
		future = new Future
		Fs.readFile path, enc, (err, st) ->
			future.return err or st
		future.wait!
	else Fs.readFileSync path, enc

export writeFile = (path, data, cb) ->
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
export exec = (cmd, opts, cb) ->
	if typeof opts is \function
		cb = opts
		opts = {stdio: \inherit}
	opts.stdio = \inherit unless opts.stdio
	opts.env = process.env unless opts.env
	cmds = cmd.split ' '
	#console.log 'spawn', cmds.0, cmds.slice(1), opts
	p = spawn cmds.0, cmds.slice(1), opts
	p.on \close (code) ->
		if code then cb new Error "exit code: "+code
		else cb code

export recursive_hardlink = (path, into, cb) ->
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

#TODO: sacar el codigo de 'el ada' y meterlo aqui
#TODO: load entire classes and save the functions in formatted test format for editing
# XXX: instead of duplicating code here just instantiate a Scope
export Config = (path, initial_obj, save_fn) ->
	#TODO: if path ends with .js/.ls then precompile it first
	#TODO: add global path
	#TODO: add file watching
	#TODO: only add the event emitter if the `on` fn is called (also ignore events if no emitter)
	debug = (require 'debug') 'config:'+path
	#EventEmitter = require \events .EventEmitter
	EventEmitter = require \eventemitter2 .EventEmitter2

	if typeof WeakMap isnt \function
		global.WeakMap = require 'es6-collections' .WeakMap
	if typeof Proxy isnt \object and not process.versions.'node-webkit' #global.window?navigator
		#debug "installing node-proxy cheat..."
		global.Proxy = Proxy = require 'node-proxy'
	# reflection is the last thing required for dynamic objects
	if typeof Reflect isnt \function then require 'harmony-reflect'

	try
		_config = Fs.readFileSync path, 'utf-8'
		_config = JSON.parse _config
	catch ex
		#throw ex
		_config = {}
		mkdir Path.dirname path

	if typeof initial_obj is \function
		save_fn = initial_obj
	else if typeof initial_obj is \object
		_config = initial_obj <<< _config

	ee = new EventEmitter
	save = _.throttle (->
		if Config._saving[path]
			debug "#path already being saved... waiting 10ms before trying again"
			# OPTIMIZE: in certain cases, maybe I could be saving twice...
			return #setTimeout save, 10ms
		Config._saving[path] = true
		obj = config #Config._[path]
		debug "saving...", path
		# used to test slow saves... 50ms delay
		/*
		future = new Future
		setTimeout ->
			future.return!
		, 50ms
		future.wait!
		#*/

		debug "writing...", path, obj
		writeFile path, JSON.stringify(obj, null, '\t'), (err) ->
			if typeof save_fn is \function => save_fn obj
			Config._saving[path] = false
			ee.emit \save obj
	), 10ms, leading: true trailing: true
	make_reflective = (o, oon, scoped_ee) ->
		oo = if Array.isArray o then [] else {}
		unless scoped_ee then scoped_ee = new EventEmitter wildcard: true
		reflective = Reflect.Proxy {}, {
			enumerable: true
			enumerate: (obj) -> Object.keys oo
			hasOwn: (obj, key) -> typeof oo[key] isnt \undefined
			keys: -> Object.keys oo
			get: (obj, name) ->
				#debug "(get-) #{oon}.%s:", name, oo[name]
				if name is \toJSON then -> oo
				#else if name is \inspect then -> JSON.stringify oo
				else if name is \inspect then -> require 'util' .inspect oo
				else if typeof(v = oo[name]) isnt \undefined then v
				else scoped_ee[name]
			set: (obj, name, val) ->
				debug "(set) #{if oon then oon+'.'+name else name} -> %s", val
				if (typeof val is \object and !_.isEqual oo[name], val) or oo[name] isnt val
					prop = if oon then "#{oon}.#{name}" else name
					#console.log "emitting... %s", prop, val
					#if config then config.emit prop, val
					#scoped_ee.emit name, val
					if name is \_all #or name is \name
						scoped_ee[name] = val
					else
						debug "set: %s -> %s", prop, val
						if typeof val is \object
							val = make_reflective val, prop
						oo[name] = val
						save!
				return val
		}
		for k, v of o => reflective[k] = v # defineProperty??
		return reflective
	Config._saving[path] = true
	Config._[path] = config = make_reflective _config, '', ee
	if initial_obj then _.each initial_obj, (v, k) ->
		if k isnt \_events
			if typeof v is \object
				config[k] = make_reflective v, k, save
			else
				Config._[path][k] = v
	/*
	Object.defineProperty config, "_events", {
		get: -> ee
	}*/

	debug "created Config object"
	Config._saving[path] = false
	config
Config._saving = {}
Config._ = {}
#Config.sync = (cb) ->
#	for k, v of Config._saving
#		if v

).run!
