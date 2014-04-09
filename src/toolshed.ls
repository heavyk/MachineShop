
Fs = require \fs
Path = require \path
Url = require \url
assert = require \assert
spawn = require \child_process .spawn
mkdirp = require \mkdirp
Rimraf = require \rimraf
printf = require \printf
export EventEmitter = require \eventemitter3 .EventEmitter

# later this will be split into current / da_funk .. but for now use lodash
# export _ = require \Current
export _ = require \lodash
export nw_version = if process.versions => process.versions.'node-webkit' else void
export v8_version = (if nw_version then \nw else \node) + '_' + process.platform + '_' + process.arch + '_' + if process.versions => process.versions.v8.match(/^([0-9]+)\.([0-9]+)\.([0-9]+)/).0 + '-' + process.versions.modules else if typeof window is \object => \browser else \unknown
export HOME_DIR = if process.platform is \win32 then process.env.USERPROFILE else process.env.HOME
export v8_mode = \Release

# maybe have a look at this:
# https://github.com/bjouhier/galaxy
# I want all functions to be called sync style
# needs to feel something like co
# https://github.com/jmar777/suspend

#TODO: implement DEBUG env variable
export Debug = (namespace) ->
	#TODO: make this a verse/fsm which maintains the list of debugs
	unless path = Debug.namespaces[namespace]
		path = process.cwd!

	if HOME_DIR
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
			console.debug "#{namespace}: #msg"
		debug.todo = !->
			msg = printf ...
			console.info "#{namespace}: [TODO] #msg"
		debug.warn = !->
			msg = printf ...
			console.warn "#{namespace}: #msg"
		debug.info = !->
			msg = printf ...
			console.info "#{namespace}: #msg"
		debug.error = !->
			msg = printf ...
			console.error "#{namespace}: #msg"
		debug.log = !->
			msg = printf ...
			console.log "#{namespace}: #msg"
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
export Future = ->
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

export rimraf = (dir, cb) ->
	if typeof cb is \function
		Rimraf dir, cb
	else
		# fixme
		Rimraf dir, ->

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
			else console.log "....", st
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

export Scope = (scope_name, initial_obj, save_fn) ->
	debug = Debug 'scope:'+scope_name
	WeakMap = global.WeakMap
	Proxy = global.Proxy
	Reflect = global.Reflect
	if typeof WeakMap is \undefined
		WeakMap = global.WeakMap = require 'es6-collections' .WeakMap
	if typeof Proxy is \undefined and not process.versions.'node-webkit' #global.window?navigator
		global.Proxy = Proxy = require 'node-proxy'
	# reflection is the last thing required for dynamic objects
	if typeof Reflect is \undefined
		require 'harmony-reflect'
		Reflect = global.Reflect
	ee = new EventEmitter
	var scope, written_json_str

	if typeof initial_obj is \function
		save_fn = initial_obj
		initial_obj = void

	iid = false
	save = ->
		clear_interval = ->
			unless Scope._saving[scope_name]
				clearInterval iid
				iid := false
		Scope._saving[scope_name]++
		if iid is false
			iid := setInterval (->
				obj = scope
				json_str = JSON.stringify obj
				if json_str isnt written_json_str
					written_json_str := json_str
					if typeof save_fn is \function => save_fn obj
					ee.emit \save obj, scope_name, json_str
					clear_interval!
				else clear_interval!
				Scope._saving[scope_name] = 0
			), 500ms
	#IMPROVEMENT: if !watch, then just load the scope and don't make it reflective
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
				else if (v = oo[name]) is 8 and oo[name+'.js']
					v = oo[name+'.js']
					args = v.match /function \((.*)\)/
					body = v.substring 1+v.indexOf('{'), v.lastIndexOf('}')
					oo[name] = Function args.1, body
				else if typeof v isnt \undefined then v
				else if oon.length is 0 then ee[name]
			set: (obj, name, val) ->
				#debug "(set) #{if oon then oon+'.'+name else name} -> %s", val
				prev_val = oo[name]
				if (typeof val is \object and !_.isEqual oo[name], val) or oo[name] isnt val
					prop = if oon then "#{oon}.#{name}" else name
					if typeof val is \object and v isnt null
						val = make_reflective val, prop
					if Array.isArray val
						debug "TODO: add the addedAt / removedAt events (see code)"
						# docs = val
						# _docs = oo[name]
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
					oo[name] = val
					ee.emit \set, prop, val, prev_val
					save!
				return val
		}
		for k, v of o => reflective[k] = v
		return reflective
	Scope._saving[scope_name] = true
	Scope._[scope_name] = scope = make_reflective {}, '', ee
	if initial_obj
		debug "initial obj: %O", initial_obj
		_.each initial_obj, (v, k) ->
			debug "k:%s, v:%O", k, v
			if typeof v is \object and v isnt null
				scope[k] = make_reflective v, k, save
			else
				Scope._[scope_name][k] = v
		Scope._saving[scope_name] = false
	return scope
# TODO: make sure this debounces, and saves later
Scope._saving = {}
Scope._ = {}

# --------------------------------
# a lot of this code is duplicated... I know :)
# they're meant to work together
# I'll fix it later....
# --------------------------------

#TODO: sacar el codigo de 'el ada' y meterlo aqui
#TODO: load entire classes and save the functions in formatted test format for editing
# XXX: instead of duplicating code here just instantiate a Scope
export Config = (path, initial_obj, opts, save_fn) ->
	#TODO: if path ends with .js/.ls then precompile it first
	#TODO: add global path
	#TODO: add file watching
	#TODO: only add the event emitter if the `on` fn is called (also ignore events if no emitter)
	debug = Debug 'config:'+path
	WeakMap = global.WeakMap
	Proxy = global.Proxy
	Reflect = global.Reflect
	if typeof WeakMap is \undefined
		global.WeakMap = WeakMap = require 'es6-collections' .WeakMap
	if typeof Proxy is \undefined and not process.versions.'node-webkit' #global.window?navigator
		debug "!!!!!!! installing node-proxy cheat..."
		global.Proxy = Proxy = require 'node-proxy'
	# reflection is the last thing required for dynamic objects
	if typeof Reflect is \undefined
		require 'harmony-reflect'
		Reflect = global.Reflect
	ee = new EventEmitter
	var config, written_json_str

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
		clear_interval = ->
			unless Config._saving[path]
				clearInterval iid
				iid := false
		Config._saving[path]++
		if iid is false
			iid := setInterval (->
				obj = config
				json_str = if opts.ugly
					JSON.stringify obj
				else
					stringify obj, stringify.get_desired_order path
				if json_str isnt written_json_str
					console.log "writing...", path
					debug "writing...", path
					writeFile path, json_str, (err) ->
						# console.log "writeFile", err
						if err
							if err.code is \ENOENT
								dirname = Path.dirname path
								console.log "WE HAVE NOENT.. creating", Path.dirname path
								mkdirp dirname, (err) ->
									if err
										ee.emit \error, err
									else save!
							else
								ee.emit \error, err
						else
							written_json_str := json_str
							if typeof save_fn is \function => save_fn obj
							ee.emit \save obj, path, json_str
						clear_interval!
				else clear_interval!
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
				prev_val = oo[name]
				if (typeof val is \object and !_.isEqual oo[name], val) or oo[name] isnt val
					prop = if oon then "#{oon}.#{name}" else name
					if typeof val is \object and v isnt null
						val = make_reflective val, prop
					oo[name] = val
					ee.emit \set, prop, val, prev_val
					save!
				return val
		}
		for k, v of o => reflective[k] = v
		return reflective
	Config._saving[path] = true
	Config._[path] = config = make_reflective {}, '', ee
	# if initial_obj then _.each initial_obj, (v, k) ->
	# 	console.log "each k: '#k' v:", v
	# 	if typeof v is \object and v isnt null
	# 		config[k] = make_reflective v, k, save
	# 	else
	# 		Config._[path][k] = v

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
				written_json_str := data
				_.each _config, (v, k) ->
					Config._[path][k] = v
			catch e
				config.emit \error e
		#TODO: make sure that we can write to the desired path before emitting \ready event
		if initial_obj
			merge config, initial_obj
		if data
			config.emit \ready, config, data
		else if Config._saving[path]
			# save!
			config.once \save ->
				debug "saved data ready"
				config.emit \ready, config, data
		Config._saving[path] = false
	return config
Config._saving = {}
Config._ = {}

#TODO: if typeof obj is \object then this function, else use JSON.stringify
regex_slash = new RegExp '\\\\', \g
regex_quote = new RegExp '"', \g
regex_newline = new RegExp '\n', \g
regex_tab = new RegExp '\t', \g
regex_tabspace = new RegExp '\t  ', \g
regex_space = new RegExp ' ', \g
regex_newspace = for i to 10 => new RegExp '\n'+(' '*i), 'g'
regex_newline = regex_newspace.0
_iindent = for i to 4 => '\t' * i # preload up to 4 indent levels
clean_str = (str) ->
	"use strict"
	(str+'').replace regex_slash, '\\\\' .replace regex_quote, '\\"' .replace regex_newline, '\\n' .replace regex_tab, '\\t'

export stringify = (obj, desired_order = [], indent = 1) ->
	out = []
	# technically, this should scale up perfectly, so there should be no holes in the array
	# assert i > 0
	unless iindent = _iindent[indent]
		iindent = _iindent[indent] = '\t' * indent

	# sort our keys alphabetically
	k = Object.keys obj .sort!
	# then, desired order keys get plaed on top in reverse order
	if (doi = desired_order.length-1) >= 0
		do
			if ~(i = k.indexOf desired_order[doi])
				kk = k.splice i, 1
				k.unshift kk.0
		while --doi >= 0

	if k.length
		for key in k
			if (o = obj[key]) is null
				out.push '"'+key+'": null'
			else switch typeof o
			| \function =>
				out.push '"'+key+'": 8'
				o = o.toString!
				key += '.js'
				if typeof obj[key] is \undefined
					fn = o.toString!
					i = fn.indexOf '('
					ii = fn.indexOf ')'
					j = fn.indexOf '{'
					jj = fn.lastIndexOf '}'
					args = fn.substring(++i, ii).replace(regex_space, '')
					body = fn.substring(++j, jj).trim!
					# console.log "#k:args:", args
					# console.log "#k:body:", body
					# console.log "#k:orig:", fn
					if ~(i = fn.indexOf '\n')
						ii = i + 1
						while fn[ii] is ' ' => ii++
						unless regex_newspace[iii = ii - i + 1 - 2]
							regex_newspace[iii] = new RegExp '\n'+(' '*iii), 'g'
						body = body.replace regex_newspace[ii - i + 1 - 2], '\n\t'
						do
							len = body.length
							body = body.replace regex_tabspace, '\t\t' # _iindent[2]
						while body.length isnt len

					#TODO: if ugly, go ahead and uglify this
					body = '\\n\\t'+clean_str(body)+'\\n' if body.length
					out.push '"'+key+'": "function('+args+'){'+body+'}"'
			| \string =>
				out.push '"'+key+'": "'+clean_str(o)+'"'
			| \number \boolean =>
				out.push '"'+key+'": '+o
			| \object =>
				if typeof o.length is \number or Array.isArray o
					if o.length
						out.push '"'+key+"\": [\n#{iindent}\t" + (_.map o, (vv) -> if typeof vv is \object then stringify vv, desired_order, indent+1 else JSON.stringify vv).join(",\n\t#{iindent}") + "\n#{iindent}]"
					else
						out.push '"'+key+'": []'
				else if o is null
					out.push '"'+key+'": null'
				else
					out.push '"'+key+'": '+stringify o, desired_order, indent+1
		return "{\n#{iindent}"+ out.join(",\n#{iindent}")+"\n#{_iindent[indent-1]}}#{if indent is 1 => '\n' else ''}"
	else if indent is 1 then "{}\n" else "{}"

da_funk_scopes = []
da_funk_callthrough = []
empty_scope = {}
da_funk_callthrough.i = 0

export da_funk = (obj, scope, refs) ->
	return {} if typeof obj isnt \object
	refs = if typeof refs isnt \object => {} else _.cloneDeep refs
	# unless refs.name
	# 	debugger
	basename = refs.name or ''
	if typeof refs.__i is \undefined
		refs.__i = 0
	# else if refs.__i++ > (refs.deep || 10)
	# 	throw new Error "too deep"
	# 	return

	if typeof scope isnt \object or not scope
		scope = {} #empty_scope
	# console.error "da_funk", scope

	f = new Function """
		if(this !== window && (typeof global !== 'object' || this !== global)) {
			for (var i in this){
				eval('var '+i+' = this[i];');
			}
		}
		return function(name, refs, args, body) {
			var fn = new Function(args, body);
			var self = this;
			var f = function() {
				// try {
					//console.log("this:", this, "self:", self)
					return fn.apply(this, arguments);
				/* } catch(e) {
					var s = (e.stack+'').split('\\n')
					//var i = 1;
					var fn_s = fn.toString().split('\\n');
					var line = /\\:([0-9]+)\\:([0-9]+)\\)$/.exec(s[1])[1] * 1;
					var sp = "          ".substr(2, (fn_s.length+'').length);
					var block = []
					fn_s.map(function(s, i) {
						i++;
						//console.log(i, line, line < (i+3), line, '<', (i+3), line > (i-3), line, '>', (i-3))
						if(line < (i+3) && line > (i-3)) block.push((i++)+":"+sp+s)
					}).join('\\n')
					console.error(s[0]+"\\n("+refs.name+" line: "+line+")\\n"+block.join('\\n'))
					//debugger;
					//console.error("Exception occured in "+name, e.stack, fn)
					//throw e;
				} */
			}
			//f.toString = function() {
			//	return "\\ncustom_func: "+name+"\\nargs: "+args+"\\nbody: "+body;
			//}
			return f
		}
		"""
	callthrough = f.call scope
	#_.each obj, (v, k) ->
	da_funk_scopes.push obj
	for k in (keys = Object.keys obj)
		v = obj[k]
		# I choose 8 because it's unlikely that an unintended value will be of value '8'
		# it takes up only one byte, and it looks like infinaty
		# it could be any number though...
		if v is 8 and typeof (fn = obj[k+'.js']) is \string
			i = fn.indexOf '('
			ii = fn.indexOf ')'
			j = fn.indexOf '{'
			jj = fn.lastIndexOf '}'
			args = fn.substring(++i, ii).replace(regex_space, '')
			# body = fn.substring(++j, jj).trim!
			refs.name = basename+'.'+k
			# console.log ":args:", args
			# console.log ":body:", body
			# console.log ":orig:", fn
			# console.log "'#body'"
			body = '"use strict"\n"' + basename + '"\n' + fn.substring(++j, jj).trim!
			# console.log "callthrough:", refs.name, callthrough, da_funk_callthrough
			obj[k] = callthrough(k, refs, args, body, new Function(args, body))

			# delete obj[k+'.js']
		# else if _.isObject v
		else if v and typeof v is \object and v isnt obj and refs.__i <= (refs.deep || 4) and v.__proto__ is ({}).__proto__
			refs.name = basename+'.'+k
			# console.log "k:", k, obj[k], v.__proto__ is Object
			refs.__i++
			da_funk obj[k], scope, refs
			refs.__i--
	obj

export objectify = (str, scope, refs) ->
	return {} unless str
	# refs = {} if typeof refs isnt \object
	if str.0 is '/' or str.0 is '.'
		str = ToolShed.readFile str

	da_funk if typeof str is \string => JSON.parse str else str, scope, refs


export merge = (a, b) ->
	keys = _.union Object.keys(a), Object.keys(b)
	for k in keys
		if b.hasOwnProperty k# and k.0 isnt '_'
			v = b[k]
			c = a[k]

			a[k] = \
			if _.isArray c
				if _.isArray v
					_.union v, c
				else if typeof v isnt \undefined
					c ++ v
				else c
			else if _.isObject(v) and _.isObject(c)
				merge c, v
			else if typeof c is \undefined => v
			else c
	return a

export extend = (a, b) ->
	# c = {}
	# keys = _.union Object.keys(a), Object.keys(b)
	if typeof b is \object
		keys = Object.keys(b)
		for k in keys
			if b.hasOwnProperty k and k.0 isnt '_'
				_k = k
				if (k.indexOf 'extend.') is 0
					_b = b[k]
					k = k.substr "extend.".length
					_a = a[k]

					# if typeof b[_k] is \function

					# if not isArray = Array.isArray _a._fnArray
					# 	_a._fnArray = []
					# debugger
				else
					_b = b[k]
					_a = a[k]
				# if ~k.indexOf '.js' and typeof _b is \string and ~_b.indexOf '1234-1111'
				# 	debugger
				a[k] = \
				if typeof _a is \function and (typeof _b is \function or (typeof a[_k] is \function or _a = b[_k]))
					# debugger
					if isArray = Array.isArray _a._fnArray
						if Array.isArray _a._fnArray
							_._fnArray.push _b
							_a
						else
							_a._fnArray = [_a, _b]
							->
								"we are _fnArray"
								for fn in this._fnArray
									fn.apply this, &
					else _b || _a
				else if _.isArray _a
					if _.isArray _b
						_.union _b, _a
					else if typeof _b isnt \undefined
						_a ++ _b
					else _a
				# else if _a isnt _b and _.isObject(_b) and _.isObject(_a)
				else if _a isnt _b and typeof _b is \object and typeof _a is \object
					extend(extend({}, _a), _b)
				# else if typeof _b is \undefined => _a else _b
				# else
				# 	if typeof _b is \object
				else _b || _a
	return a


export embody = (obj) ->
	deps = {}
	i = &.length
	while i-- > 1
		if _.isObject a = &[i]
			deps = extend deps, a
	merge obj, deps

stringify.get_desired_order = (path) ->
	# TODO: add more cases for common config fles (bower, browserify, etc.)
	# TODO: add higher-depth object ordering as well. ex:
	# desired_order.subpaths.'sencillo' = <[universe creator]>
	# desired_order.subpaths.'a.long.subpath' = <[a good ordering]>
	switch Path.basename path
	| \component.json \package.json =>
		<[name version description homepage author contributors maintainers]>
	| otherwise => []

export debug_fn = (namespace, cb, not_fn) ->
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
