// this is MUUUUUY PROVISIONAL
var LiveScript, ToolShed, Machina, Fsm, e, _, fsm, Debug, out$ = typeof exports != 'undefined' && exports || this;
// try {
	// //throw new Error
  out$.LiveScript = LiveScript = require('LiveScript');
  out$.ToolShed = ToolShed = require('./src/toolshed');
  out$.Machina = Machina = require('./src/machina').Machina;

  fsm = require('./src/fsm');
  out$.Fsm = Fsm = fsm.Fsm;
  out$.Fabuloso = fsm.Fabuloso;
// } catch (e$) {
// //   e = e$;
// 	console.log("ERROR:", e$.stack)
//   throw(e$);
//   fsm = require('./lib/fsm');
//   out$.ToolShed = ToolShed = require('./lib/toolshed');

//   out$.Fsm = fsm.Fsm;
//   out$.Fabuloso = fsm.Fabuloso;
//   out$.pipeline = fsm.pipeline;
//   out$.Machina = Machina = require('./lib/machina').Machina;
// }
out$.Config = Config = ToolShed.Config;
out$._ = _ = ToolShed._;
out$.Debug = Debug = require('debug');
console.log("debug", exports.Debug)