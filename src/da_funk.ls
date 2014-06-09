
_ = require \lodash
Path = require \path

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

stringify = (obj, desired_order = [], indent = 1) ->
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

da_funk = (obj, scope, refs) ->
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

objectify = (str, scope, refs) ->
	return {} unless str
	# refs = {} if typeof refs isnt \object
	if str.0 is '/' or str.0 is '.'
		str = ToolShed.readFile str

	da_funk if typeof str is \string => JSON.parse str else str, scope, refs


merge = (a, b) ->
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

extend = (a, b) ->
	# c = {}
	# keys = _.union Object.keys(a), Object.keys(b)
	if typeof b is \object
		keys = Object.keys(b)
		for k in keys
			if b.hasOwnProperty k and k.0 isnt '_'
				_k = k
				if (k.indexOf 'and|') is 0
					_b = b[k]
					k = k.substr "and|".length
					_a = a[k]
				else
					_b = b[k]
					_a = a[k]
				a[k] = \
				if typeof _a is \function and (typeof _b is \function or (typeof a[_k] is \function or _a = b[_k]))
					if isArray = Array.isArray _a._fnArray
						_a._fnArray.unshift _b
						_a
					else
						_a._fnArray = [_a, _b]
						((_fn) ->
							return ->
								for fn in _fn._fnArray
									fn.apply this, &)(a[k])
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

# DaFunk.formula obj, \improves, another
# gatta give a shout out to bootsie for his basic funk formula
# yt: IHE6hZU72A4, 2Sh9cezHNec
formula = (a, op, b) ->



embody = (obj) ->
	deps = {}
	i = &.length
	while i-- > 1
		if _.isObject a = &[i]
			deps = extend deps, a
	merge obj, deps

stringify.desired_order = (path) ->
	# TODO: add more cases for common config fles (bower, browserify, etc.)
	# TODO: add higher-depth object ordering as well. ex:
	# desired_order.subpaths.'sencillo' = <[universe creator]>
	# desired_order.subpaths.'a.long.subpath' = <[a good ordering]>
	switch Path.basename path
	| \component.json \package.json =>
		<[name version description homepage author contributors maintainers]>
	| otherwise => []

export stringify
export da_funk
export objectify
export merge
export extend
export embody