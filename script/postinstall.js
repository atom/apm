#!/usr/bin/env node

var cp = require('child_process')
var fs = require('fs')
var path = require('path')

var script = path.join(__dirname, 'postinstall')
if (process.platform === 'win32') {
  script += '.cmd'
} else {
  script += '.sh'
}

// Make sure all the scripts have the necessary permissions when we execute them
// (npm does not preserve permissions when publishing packages on Windows,
// so this is especially needed to allow apm to be published successfully on Windows)
fs.chmodSync(script, 0o755)
fs.chmodSync(path.join(__dirname, '..', 'bin', 'apm'), 0o755)
fs.chmodSync(path.join(__dirname, '..', 'bin', 'npm'), 0o755)
fs.chmodSync(path.join(__dirname, '..', 'bin', 'python-interceptor.sh'), 0o755)

var child = cp.spawn(script, [], { stdio: ['pipe', 'pipe', 'pipe'], shell: true })
child.stderr.pipe(process.stderr)
child.stdout.pipe(process.stdout)
