var LiveScript, ToolShed, Fsm, e, _, Debug, out$ = typeof exports != 'undefined' && exports || this;
try {
  out$.LiveScript = LiveScript = require('LiveScript');
  out$.ToolShed = ToolShed = require('./src/toolshed');
  out$.Fsm = Fsm = require('./src/fsm').Fsm;
} catch (e$) {
  e = e$;
  out$.ToolShed = ToolShed = require('./lib/toolshed');
  out$.Fsm = Fsm = require('./lib/fsm').Fsm;
}
out$._ = _ = require('lodash');
out$.Debug = Debug = require('debug');