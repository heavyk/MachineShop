

Scope = (scope_name, initial_obj, save_fn) ->
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

export Scope