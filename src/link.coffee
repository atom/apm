fs = require 'fs-extra'
path = require 'path'

CSON = require 'season'
yargs = require 'yargs'

Command = require './command'
config = require './apm'

module.exports =
class Link extends Command
  @commandNames: ['link', 'ln']

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))
    options.usage """

      Usage: apm link [<package_path>] [--name <package_name>]

      Create a symlink for the package in ~/.atom/packages. The package in the
      current working directory is linked if no path is given.

      Run `apm links` to view all the currently linked packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('d', 'dev').boolean('dev').describe('dev', 'Link to ~/.atom/dev/packages')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    packagePath = options.argv._[0]?.toString() ? '.'
    linkPath = path.resolve(process.cwd(), packagePath)

    packageName = options.argv.name
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name unless packageName
    packageName = path.basename(linkPath) unless packageName

    if options.argv.dev
      targetPath = path.join(config.getAtomDirectory(), 'dev', 'packages', packageName)
    else
      targetPath = path.join(config.getAtomDirectory(), 'packages', packageName)

    unless fs.existsSync(linkPath)
      callback("Package directory does not exist: #{linkPath}")
      return

    try
      if fs.existsSync(targetPath) and fs.lstatSync(targetPath).isSymbolicLink()
        fs.unlinkSync(targetPath)

      fs.mkdirpSync path.dirname(targetPath)
      fs.symlinkSync(linkPath, targetPath, 'junction')
      console.log "#{targetPath} -> #{linkPath}"
      callback()
    catch error
      callback("Linking #{targetPath} to #{linkPath} failed: #{error.message}")
