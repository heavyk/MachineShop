# Machine Shop!!

try
	export LiveScript = require \LiveScript
	export ToolShed = require \./src/toolshed
	export Fsm = require \./src/fsm .Fsm
catch e
	export ToolShed = require \./lib/toolshed
	export Fsm = require \./lib/fsm .Fsm
export _ = require \lodash
export Debug = require \debug
