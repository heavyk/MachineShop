// this is MUUUUUY PROVISIONAL
var LiveScript, ToolShed, Fsm, e, _, fsm, Debug, out$ = typeof exports != 'undefined' && exports || this;
try {
	// //throw new Error
  out$.LiveScript = LiveScript = require('LiveScript');
  out$.ToolShed = ToolShed = require('./src/toolshed');
  fsm = require('./src/fsm');
  out$.Fsm = Fsm = fsm.Fsm;
  out$.Fabuloso = fsm.Fabuloso;
} catch (e$) {
//   e = e$;
	console.log("ERROR:", e$.stack)
  out$.ToolShed = ToolShed = require('./lib/toolshed');
  var fsm = require('./lib/fsm')
  out$.Fsm = fsm.Fsm;
  out$.Fabuloso = fsm.Fabuloso;
}
out$.Config = Config = ToolShed.Config;
out$._ = _ = ToolShed._;
out$.Debug = Debug = require('debug');