path = require 'path'

async = require 'async'
CSON = require 'season'
yargs = require 'yargs'
_ = require 'underscore-plus'

Command = require './command'
config = require './apm'
fs = require './fs'

module.exports =
class Clean extends Command
  @commandNames: ['clean', 'prune']

  constructor: ->
    super()
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))

    options.usage """
      Usage: apm clean

      Deletes all packages in the node_modules folder that are not referenced
      as a dependency in the package.json file.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  run: (options) ->
    process.stdout.write("Removing extraneous modules ")
    @fork @atomNpmPath, ['prune'], (args...) =>
      @logCommandResults(options.callback, args...)
