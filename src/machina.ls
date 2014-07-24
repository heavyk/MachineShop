Postal = require \postal
ToolShed = require './toolshed'
DaFunk = require './da_funk'
{ Fsm, collective, pipeline } = require './fsm'

# TODO: new class: `ActiveUri` :: gets uri changes and sets them in real time, does fires events and shit
# - this may be useful for sessions or something
# - it could also be useful for Perspective
#   - for it to be useful to Perspectice
Url = require \url
QueryString = require \querystring
class Uri
	(uri) ->
		if typeof uri is \string
			@update uri


	update: (uri) !->
		@_uri = uri.trim!
		@ <<< u = Url.parse uri
		if u.query
			q = QueryString.parse
			@version = q.version
		unless @version
			@version = \latest
		@protocol = @protocol.substr 0, @protocol.length - 1



	resolve: ->
	fsm:~ -> @toString \fsm
	state:~ -> @toString \state
	machina:~ -> @toString \machina
	stringify: -> @toString ...
	toString: ->
		str = "#{@protocol}://"#{@host}
		str += @_uri.substr str.length, @host.length
		str += @pathname if it is \fsm or it is \state
		str += '?'+@query if @query
		str += '#'+@hash if @hash and it is \state
		return str


Uri.parse = (uri) ->
	ref = proto: \blueprint, version: \latest

	if typeof uri is \string
		if ~(i = uri.indexOf '://')
			ref.proto = uri.substr 0, i
			uri = uri.substr i+3
		if ~(i = uri.indexOf ':')
			ref.origin = uri.substr 0, i
			ref.path = uri.substr i+1
			if ~(i = uri.indexOf '@')
				ref.version = uri.substr i+1
				ref.path = uri.substr 0, i
	else if typeof uri is \object
		ref = uri
		# @debug.warn "TODO: uri objects"
	return ref

uri = new Uri "blueprint://Poem:1234/Affinaty?lala=1234"
console.log "uri:", {machina: uri.machina, state: uri.state, fsm: uri.fsm}

# later, in the future, integrate this with [node] webworker threads
# or maybe something like thread.js

# TODO: do a bunch of hardcore streaming on it :)
#   lol, I meant pipes, silly
# p$ = require \procstreams

# TODO: Architect has the Blueprint
# TODO: Architect imbues the Blueprint - creates a Fsm
# TODO: each Fsm is registered with the appropriate Machina
# ---------
# wait, in the future, we could just make, for example, a comment list a Machina...
# Verse extends Machina - a machina represents organization
# Architect/Blueprint/Meaning
class Manufactory extends Fsm
	protocol: \Cardinal
	(encantador, incantation, version, opts) ->
		# TODO --- check for wildcards
		if typeof incantation isnt \string
			throw new Error "you must have an incantation to define your Manufactory properly"
		if typeof encantador isnt \string
			throw new Error "you must have an encantador to define your Manufactory properly"
		if typeof version isnt \string
			opts = version if typeof version is \object
			version = \latest
		# technically, version can have wildcards though...
		# TODO -- do the semver transition

		@encantador = encantador
		@incantation = incantation
		@version = version
		@_channel = Url.parse "cardinal://#encantador/#incantation"
		super "Manufactory(#incantation@#version)"

	initialize: ->
		@channel = Postal.channel @_channel
	states:
		uninitialized:
			onenter: ->
				console.log "#{@namespace}: going to open channel: '#{@channel}'"
				console.log "#{@namespace}: going to open channel: '#{@channel}'"
				@transition @
class Architect extends Fsm
	(protocol, blueprint) ->
		if not protocol
			throw new Error "your machina needs a protocol"
		if not blueprint
			throw new Error "your machina needs a blueprint"
		concept = blueprint.concept #+'-'+blueprint.version
		return exists if (exists = @@_[concept]) instanceof Architect

		unless opts.channel
			@channel = Postal.channel "#protocol://#concept"

		DaFunk.extend this, Fsm.Empathy

		super "Architect(#concept)"
		if @channels
			for key in Object.keys @channels
				pipeline.subscribe "#concept:added" (data, dispatch) ->
					key = "unknown"
					if data and data._key
						key = data._key
						console.log "added fsm://#concept/#key"
					else
						console.log "added fsm://#concept/#key"

		@@_[concept] = @

	@@get = (concept) ->
		if (m = @@_[concept]) is void
			m = new Architect concept
		return m

	messages:
		patch: (diff, etc) ->
			#TODO !!!*** send the blueprint the patch
			#TODO !!!*** if there are any machinas, send them a message to reboot/re-render, etc


# TODO: in each class have it make a Machina automatically to hold the instantiations (much easier this way)
# a Machina will receive an instantiation. each instantiation will be automatically added
# TODO: sometime in the future, the machina will take hints from the StoryBook to know when to delete some of itself
# Machina should probably extend Organization
# Quest should extend Machina
# Verse should extend Machina ???
# Implementation should extend Machina
# Library should extend Machina
# ExperienceDB should DEFINITELY extend Machina

class Machina extends Fsm
	(@encantador, @incantation, opts) ->
		# TODO ----!~ do model name checking (to verify nothing weird is going on)...
		# has to be [a-zA-Z_]+[a-zA-Z0-9_]+
		# eg. 2 letter minimum. can't start with a number. only underscore is allowed. no '-', '/', '&', or '?'
		if not protocol
			throw new Error "your machina needs to know the protocol to listen on"
		if not implementation
			throw new Error "your machina needs to know the incantation"

		@_channel = "#{protocol}://#{id}"
		@channel = Postal.channel @_channel
		@channel.subscribe @_channel, (data, dispatch) ->
			console.log "got a message!", &
			if dispatch.event
				for k, v of @'dispatch.event'
					console.log "Machina.dispatch"

		# reserved for future use:
		@motivation = []
		@collaboration = {}
		# a list of all instances of this implementation
		@collective = {}
		# unless opts.channel
		# 	@channel = Postal.channel "fsm://#id"

		DaFunk.extend this, Fsm.Empathy
		super "Machina(#id)", opts

		# for each new Fsm added:
		# @channel.subscribe "#{protocol}://#{id}/#k", (data, dispatch) ->


	# eventListeners:
	# 	transition: ->
	messages:
		added: (data, dispatch) ->
			console.log "yay do something here..."

	states:
		uninitialized:
			onenter: ->
				@transition '/'

		'/':
			onenter: ->
				@debug "machina ready!"
Machina._ = {}
class Machinator extends Fsm
	(@protocol, @implementation, opts) ->
		# TODO ----!~ do model name checking (to verify nothing weird is going on)...
		# has to be [a-zA-Z_]+[a-zA-Z0-9_]+
		# eg. 2 letter minimum. can't start with a number. only underscore is allowed. no '-', '/', '&', or '?'
		if not protocol
			throw new Error "your machina needs to know the protocol to listen on"
		if not implementation
			throw new Error "your machina needs to know the incantation"

		@_channel = "#{protocol}://#{id}"
		@channel = Postal.channel @_channel
		@channel.subscribe @_channel, (data, dispatch) ->
			console.log "got a message!", &
			if dispatch.event
				for k, v of @'dispatch.event'
					console.log "Machina.dispatch"

		# reserved for future use:
		@motivation = []
		@collaboration = {}
		# a list of all instances of this implementation
		@collective = {}
		# unless opts.channel
		# 	@channel = Postal.channel "fsm://#id"

		DaFunk.extend this, Fsm.Empathy
		super "Machina(#id)", opts

		# for each new Fsm added:
		# @channel.subscribe "#{protocol}://#{id}/#k", (data, dispatch) ->


	# eventListeners:
	# 	transition: ->
	messages:
		added: (data, dispatch) ->
			console.log "yay do something here..."

	states:
		uninitialized:
			onenter: ->
				@transition '/'

		'/':
			onenter: ->
				@debug "machina ready!"

	@@get = (xid) ->
		Machina

Machina.pipeline = pipeline
export Machina

# if typeof process is \object and process.env.MACHINA
# 	# Machina = require './machina' .Machina
# 	_machina = new Machina
# Object.defineProperty exports, "pepino",
# 	get: ->
# 		if not _machina
# 			_machina := new Machina
# 		return _machina