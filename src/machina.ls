ToolShed = require './toolshed'
{ Fsm, Fabuloso, collective, pipeline } = require './fsm'

# later, in the future, integrate this with [node] webworker threads
# or maybe something like thread.js

# TODO: do a bunch of hardcore streaming on it :)
#   lol, I meant pipes, silly
# p$ = require \procstreams
class Machina extends Fsm
	(name) ->
		# TODO: calculate cores and shit
		@fsms = []
		ToolShed.extend @, Fabuloso
		super "Machina"

	eventListeners:
		'Fsm:added': (fsm) ->
			@fsms.push fsm

	states:
		uninitialized:
			onenter: ->
				# switch OS
				# | \osx =>
				# 	CORES := $p "sysctl hw.ncpu" .pipe "awk '{print $2}'" .data (err, stdout, stderr) ->
				# 		if stdout then CORES := Math.round (''+stdout) * 1
				# | \linux =>
				# 	CORES := $p "grep -c ^processor /proc/cpuinfo" .data (err, stdout, stderr) ->
				# 		if stdout then CORES := Math.round (''+stdout) * 1
				@transition \ready

		ready:
			onenter: ->
				@debug "machina ready!"

# if typeof process is \object and process.env.MACHINA
# 	# Machina = require './machina' .Machina
# 	_machina = new Machina
# Object.defineProperty exports, "pepino",
# 	get: ->
# 		if not _machina
# 			_machina := new Machina
# 		return _machina