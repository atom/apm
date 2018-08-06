var path = require('path')
var cp = require('child_process')

var script = path.join(__dirname, 'postinstall')
if (process.platform.indexOf('win') === 0) {
  script += '.cmd'
} else {
  script += '.sh'
}
var child = cp.spawn(script, [], { stdio: ['pipe', 'pipe', 'pipe'], shell: true })
child.stderr.pipe(process.stderr)
child.stdout.pipe(process.stdout)
