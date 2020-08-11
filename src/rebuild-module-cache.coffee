fs = require 'fs-extra'
path = require 'path'

async = require 'async'
yargs = require 'yargs'

Command = require './command'
config = require './apm'

module.exports =
class RebuildModuleCache extends Command
  @commandNames: ['rebuild-module-cache']

  constructor: ->
    super()
    @atomPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))
    options.usage """

      Usage: apm rebuild-module-cache

      Rebuild the module cache for all the packages installed to
      ~/.atom/packages

      You can see the state of the module cache for a package by looking
      at the _atomModuleCache property in the package's package.json file.

      This command skips all linked packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  getResourcePath: (callback) ->
    if @resourcePath
      process.nextTick => callback(@resourcePath)
    else
      config.getResourcePath (@resourcePath) => callback(@resourcePath)

  rebuild: (packageDirectory, callback) ->
    @getResourcePath (resourcePath) =>
      try
        @moduleCache ?= require(path.join(resourcePath, 'src', 'module-cache'))
        @moduleCache.create(packageDirectory)
      catch error
        return callback(error)

      callback()

  run: (options) ->
    {callback} = options

    commands = []
    try
      for packageName in fs.readdirSync(@atomPackagesDirectory)
        packageDirectory = path.join(@atomPackagesDirectory, packageName)
        try
          continue if fs.lstatSync(packageDirectory).isSymbolicLink()
          continue unless fs.statSync(path.join(packageDirectory, 'package.json')).isFile()
        catch error
          # If either error, we don't want to keep going
          continue

        commands.push (callback) =>
          process.stdout.write "Rebuilding #{packageName} module cache "
          @rebuild packageDirectory, (error) =>
            if error?
              @logFailure()
            else
              @logSuccess()
            callback(error)
    catch error
      # readdir failed - just fall through and use an empty array for commands

    async.waterfall(commands, callback)
