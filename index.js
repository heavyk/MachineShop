// this is MUUUUUY PROVISIONAL
var LiveScript, ToolShed, Fsm, e, _, Debug, out$ = typeof exports != 'undefined' && exports || this;
// try {
	// //throw new Error
 //  out$.LiveScript = LiveScript = require('LiveScript');
 //  out$.ToolShed = ToolShed = require('./src/toolshed');
 //  out$.Fsm = Fsm = require('./src/fsm').Fsm;
// } catch (e$) {
//   e = e$;
  out$.ToolShed = ToolShed = require('./lib/toolshed');
  var fsm = require('./lib/fsm')
  out$.Fsm = fsm.Fsm;
  out$.Fabuloso = fsm.Fabuloso;
// }
out$.Config = Config = ToolShed.Config;
out$._ = _ = ToolShed._;
out$.Debug = Debug = require('debug');