// this is MUUUUUY PROVISIONAL
var LiveScript, ToolShed, Machina, Fsm, e, _, fsm, Debug, out$ = typeof exports != 'undefined' && exports || this;
// try {
	// //throw new Error
  out$._ = _ = require('lodash');
  out$.LiveScript = LiveScript = require('LiveScript');

  out$.DaFunk = DaFunk = require('./src/da_funk');
  out$.ToolShed = ToolShed = require('./src/toolshed');

  out$.Scope = Scope = require('./src/scope').Scope;
  out$.Config = Config = require('./src/config').Config;
  out$.Machina = Machina = require('./src/machina').Machina;

  out$.Fsm = Fsm = require('./src/fsm').Fsm;
  out$.Empathy = Fsm.Empathy;
  ToolShed.extend = DaFunk.extend
  // ToolShed.extend = DaFunk.basic.formula
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

out$.Debug = Debug = require('debug');