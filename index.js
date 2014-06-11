// this is MUUUUUY PROVISIONAL
var LiveScript, ToolShed, Machina, Fsm, e, _, fsm, Debug, out$ = typeof exports != 'undefined' && exports || this;
  out$._ = _ = require('lodash');

// this is a stupid hack to trick out browserify (otherwise it says errors about src/... not found (it doesn't know about .ls extension))
if(require && require.extensions && require.extensions['.ls']) {
  var dir = './src'
  out$.DaFunk = DaFunk = require(dir + '/da_funk');
  out$.ToolShed = ToolShed = require(dir + '/toolshed');
  out$.Scope = Scope = require(dir + '/scope').Scope;
  out$.Config = Config = require(dir + '/config').Config;
  out$.Machina = Machina = require(dir + '/machina').Machina;
  out$.Fsm = Fsm = require(dir + '/fsm').Fsm;
} else {
  out$.DaFunk = DaFunk = require('./lib/da_funk');
  out$.ToolShed = ToolShed = require('./lib/toolshed');
  out$.Scope = Scope = require('./lib/scope').Scope;
  out$.Config = Config = require('./lib/config').Config;
  out$.Machina = Machina = require('./lib/machina').Machina;
  out$.Fsm = Fsm = require('./lib/fsm').Fsm;
}

// out$.Empathy = Fsm.Empathy;
console.log("out:", out$)
ToolShed.extend = DaFunk.extend
// ToolShed.extend = DaFunk.basic.formula
out$.Debug = Debug = ToolShed.Debug;