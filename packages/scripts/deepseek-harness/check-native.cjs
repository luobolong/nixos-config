const path = require("node:path");
const pty = require(path.join(process.env.APP, "node_modules/node-pty"));
require(path.join(process.env.APP, "node_modules/koffi"));
require(path.join(process.env.APP, "node_modules/node-addon-require-builtin"));
require(path.join(process.env.APP, "node_modules/sharp"));
const child = pty.spawn(process.env.TEST_SHELL, ["-c", "printf pty-ok"], {
  cols: 80,
  rows: 24,
});
let output = "";
child.onData((data) => output += data);
child.onExit(({ exitCode }) => {
  if (exitCode !== 0 || !output.includes("pty-ok")) process.exit(1);
});
