
{ Debug, EventEmitter, _ } = ToolShed = require './toolshed'

DaFunk = require './da_funk'
Fs = require \fs
Path = require \path

# --------------------------------
# a lot of this code is duplicated with Scope... I know :)
# they're meant to work together
# I'll fix it later....
# --------------------------------

#TODO: sacar el codigo de 'el ada' y meterlo aqui
#TODO: load entire classes and save the functions in formatted test format for editing
# XXX: instead of duplicating code here just instantiate a Scope
Config = (path, initial_obj, opts, save_fn) ->
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
		# debug "!!!!!!! installing node-proxy cheat..."
		debug "!!!!!!! installing node-proxy cheat..."
		global.Proxy = Proxy = require 'node-proxy'
	# reflection is the last thing required for dynamic objects
	if typeof Reflect is \undefined
		require 'harmony-reflect'
		Reflect = global.Reflect
		Proxy = global.Proxy
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
				json_str = if opts.ugly => JSON.stringify obj else DaFunk.stringify obj, DaFunk.stringify.desired_order path
				# console.log "json", json_str
				if json_str isnt written_json_str
					Fs.writeFile path, json_str, (err) ->
					# Fs.writeFile path, written_json_str, (err) ->
						if err
							if err.code is \ENOENT
								dirname = Path.dirname path
								ToolShed.mkdir dirname, (err) ->
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
		reflective = Proxy oo, {
			enumerable: true
			enumerate: (obj) -> Object.keys oo
			hasOwn: (obj, key) -> typeof oo[key] isnt \undefined
			keys: -> Object.keys oo
			get: (obj, name) ->
				# debug "(get) #{oon}.%s:", name, oo[name]
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
				# debug "(set) #{if oon then oon+'.'+name else name} -> %s", val
				prev_val = oo[name]
				if (typeof val is \object and !_.isEqual oo[name], val) or oo[name] isnt val
					prop = if oon then "#{oon}.#{name}" else name
					if typeof val is \object and val isnt null => val = make_reflective val, prop
					oo[name] = val
					ee.emit \set, prop, val, prev_val
					save!
				return val
		}
		for k, v of o
			oo[k] := v
			# reflective[k] = v
		return reflective
	# Config._saving[path] = true
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
				config.emit \error e.stack
		#TODO: make sure that we can write to the desired path before emitting \ready event
		if initial_obj
			DaFunk.merge config, initial_obj

		if data
			config.emit \ready, config, data
		else if Config._saving[path]
			# save!
			config.once \save ->
				debug "saved data ready"
				config.emit \ready, config, data
		else
			config.emit \ready, config, data
		# Config._saving[path] = false
	return config
Config._saving = {}
Config._ = {}

export Config