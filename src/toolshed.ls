
Fs = require \fs
Path = require \path
Url = require \url
spawn = require('child_process').spawn
_ = require \lodash
mkdirp = require 'mkdirp'
debug = (require 'debug') 'ToolShed'

export nw_version = process.versions.'node-webkit'
export v8_version = (if nw_version then \nw else \node) + '_' + process.platform + '_' + process.arch + '_' + process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/).0
export HOME_DIR = if process.platform is \win32 then process.env.USERPROFILE else process.env.HOME
export v8_mode = \Release

# XXX - I REALLY want to integrate fiber support into sencillo
#     - it should be transparent to the programmer whether it's a sync func or not
# in the case of node-webkit or node-0.11.3+, it should use yield
# in the case of node normal it should use fibers or gnode style of yield (whichever is faster)
Fiber = ->

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
	p = spawn cmds.0, cmds.slice(1), opts
	p.on \close (code) ->
		if code then cb new Error "exit code: "+code
		else cb code

export searchDownwardFor = (file, dir, cb) ->
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
	test_dir dir

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
export Config = (path, initial_obj, opts, save_fn) ->
	#TODO: if path ends with .js/.ls then precompile it first
	#TODO: add global path
	#TODO: add file watching
	#TODO: only add the event emitter if the `on` fn is called (also ignore events if no emitter)
	debug = (require 'debug') 'config:'+path
	EventEmitter = require \events .EventEmitter
	WeakMap = global.WeakMap
	Proxy = global.Proxy
	Reflect = global.Reflect
	if typeof WeakMap is \undefined
		WeakMap = global.WeakMap = require 'es6-collections' .WeakMap
	if typeof Proxy is \undefined and not process.versions.'node-webkit' #global.window?navigator
		debug "!!!!!!! installing node-proxy cheat..."
		global.Proxy = Proxy = require 'node-proxy'
	# reflection is the last thing required for dynamic objects
	if typeof Reflect is \undefined
		require 'harmony-reflect'
		Reflect = global.Reflect
	ee = new EventEmitter
	var config

	if typeof initial_obj is \function
		# we're just gonna assume, that the last argument is a function.
		# if it's not, you're calling it wrong!
		opts = {+watch}
		save_fn = initial_obj
	else if typeof opts is \function
		save_fn = opts
		opts = {+watch}
	if typeof opts is \undefined
		opts = {+watch}

	iid = false
	save = ->
		Config._saving[path]++
		if iid is false
			iid := setInterval (->
				obj = config
				debug "writing...", path

				json_str = if opts.ugly
					JSON.stringify obj
				else
					stringify obj, 1, stringify.get_desired_order path
				writeFile path, json_str, (err) ->
					if typeof save_fn is \function => save_fn obj
					ee.emit \save obj, path
					unless Config._saving[path]
						clearInterval iid
						iid := false
				Config._saving[path] = 0
			), 500ms
	#IMPROVEMENT: if !watch, then just load the config and don't make it reflective
	make_reflective = (o, oon) ->
		oo = if Array.isArray o then [] else {}
		reflective = Reflect.Proxy oo, {
			enumerable: true
			enumerate: (obj) -> Object.keys oo
			hasOwn: (obj, key) -> typeof oo[key] isnt \undefined
			keys: -> Object.keys oo
			get: (obj, name) ->
				#debug "(get-) #{oon}.%s:", name, oo[name]
				if name is \toJSON then -> oo
				else if name is \inspect then -> require 'util' .inspect oo
				else if (v = oo[name]) is null and oo[name+'.js']
					v = oo[name+'.js']
					args = v.match /function \((.*)\)/
					body = v.substring 1+v.indexOf('{'), v.lastIndexOf('}')
					oo[name] = Function args.1, body
				else if typeof v isnt \undefined then v
				else if oon.length is 0 then ee[name]
			set: (obj, name, val) ->
				#debug "(set) #{if oon then oon+'.'+name else name} -> %s", val
				if (typeof val is \object and !_.isEqual oo[name], val) or oo[name] isnt val
					prop = if oon then "#{oon}.#{name}" else name
					if typeof val is \object and v isnt null
						val = make_reflective val, prop
					oo[name] = val
					ee.emit \set, prop, val
					save!
				return val
		}
		for k, v of o => reflective[k] = v
		return reflective
	Config._saving[path] = true
	Config._[path] = config = make_reflective {}, '', ee
	if initial_obj then _.each initial_obj, (v, k) ->
		if k isnt \_events
			if typeof v is \object and v isnt null
				config[k] = make_reflective v, k, save
			else
				Config._[path][k] = v

	Fs.readFile path, 'utf-8', (err, data) ->
		is_new = false
		if err
			if err.code is \ENOENT
				config.emit \new
				is_new = true
			else
				config.emit \error e
		else
			try
				_config = JSON.parse data
				_.each _config, (v, k) ->
					Config._[path][k] = v
			catch e
				config.emit \error e
			finally
				config.emit \ready, config, path
		#TODO: make sure that we can write to the desired path before emitting \ready event
		config.emit \ready, config, is_new
		Config._saving[path] = false
	return config
Config._saving = {}
Config._ = {}

#TODO: if typeof obj is \object then this function, else use JSON.stringify
export stringify = (obj, indent = 1, desired_order = []) ->
	out = []
	iindent = '\t' * indent

	# sort our keys alphabetically
	k = Object.keys obj .sort!
	# then, desired order keys get plaed on top in reverse order
	if (doi = desired_order.length-1) >= 0
		do
			if ~(i = k.indexOf desired_order[doi])
				kk = k.splice i, 1
				k.unshift kk.0
		while --doi >= 0

	for key in k
		if (o = obj[key]) is null
			out.push '"'+key+'": null'
		else switch typeof o
		| \function =>
			out.push '"'+key+'": null'
			o = o.toString!
			key += '.js'
			if typeof obj[key] is \undefined
				out.push '"'+key+'": "'+o.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')+'"'
		| \string =>
			out.push '"'+key+'": "'+o.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')+'"'
		| \number \boolean =>
			out.push '"'+key+'": '+o
		| \object =>
			if key is \keywords or typeof o.length is \number or Array.isArray o
				out.push '"'+key+"\": [\n#{iindent}\t" + (_.map o, (vv) -> if typeof vv is \object then stringify vv, indent+1 else JSON.stringify vv).join(",\n\t#{iindent}") + "\n#{iindent}]"
			else if o is null
				out.push '"'+key+'": null'
			else
				out.push '"'+key+'": '+stringify o, indent+1
	return "{\n#{iindent}"+ out.join(",\n#{iindent}")+"\n#{'\t' * (indent-1)}}"

stringify.get_desired_order = (path) ->
	# TODO: add more cases for common config fles (bower, browserify, etc.)
	# TODO: add higher-depth object ordering as well. ex:
	# desired_order.subpaths.'sencillo' = <[universe creator]>
	# desired_order.subpaths.'a.long.subpath' = <[a good ordering]>
	switch Path.basename path
	| \component.json \package.json =>
		<[name version description homepage author contributors maintainers]>
	| otherwise => []
