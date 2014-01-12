# Machine Shop!!

try
	export LiveScript = require \LiveScript
	export ToolShed = require \./src/toolshed
	export Fsm = require \./src/fsm .Fsm
catch e
	export ToolShed = require \./lib/toolshed
	export Fsm = require \./lib/fsm .Fsm
export _ = require \lodash
export Config = ToolShed.Config
export Debug = require \debug
#TODO: do a custom version of EventEmitter2
export EventEmitter = require \events .EventEmitter
