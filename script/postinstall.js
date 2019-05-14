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

// Read + execute permission
fs.chmodSync(script, fs.constants.S_IRUSR | fs.constants.S_IXUSR)
fs.chmodSync(path.join(__dirname, '..', 'bin', 'apm'), fs.constants.S_IRUSR | fs.constants.S_IXUSR)
fs.chmodSync(path.join(__dirname, '..', 'bin', 'npm'), fs.constants.S_IRUSR | fs.constants.S_IXUSR)
fs.chmodSync(path.join(__dirname, '..', 'bin', 'python-interceptor.sh'), fs.constants.S_IRUSR | fs.constants.S_IXUSR)

var child = cp.spawn(script, [], { stdio: ['pipe', 'pipe', 'pipe'], shell: true })
child.stderr.pipe(process.stderr)
child.stdout.pipe(process.stdout)
