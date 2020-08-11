fs = require 'fs-extra'
path = require 'path'

async = require 'async'
_ = require 'underscore-plus'
yargs = require 'yargs'

config = require './apm'
Command = require './command'

module.exports =
class Dedupe extends Command
  @commandNames: ['dedupe']

  constructor: ->
    super()
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))
    options.usage """

      Usage: apm dedupe [<package_name>...]

      Reduce duplication in the node_modules folder in the current directory.

      This command is experimental.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  dedupeModules: (options, callback) ->
    process.stdout.write 'Deduping modules '

    @forkDedupeCommand options, (args...) =>
      @logCommandResults(callback, args...)

  forkDedupeCommand: (options, callback) ->
    dedupeArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'dedupe']
    dedupeArgs.push(@getNpmBuildFlags()...)
    dedupeArgs.push('--silent') if options.argv.silent
    dedupeArgs.push('--quiet') if options.argv.quiet

    if vsArgs = @getVisualStudioFlags()
      dedupeArgs.push(vsArgs)

    dedupeArgs.push(packageName) for packageName in options.argv._

    fs.mkdirpSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @addBuildEnvVars(env)

    dedupeOptions = {env}
    dedupeOptions.cwd = options.cwd if options.cwd

    @fork(@atomNpmPath, dedupeArgs, dedupeOptions, callback)

  createAtomDirectories: ->
    fs.mkdirpSync(@atomDirectory)
    fs.mkdirpSync(@atomNodeDirectory)

  run: (options) ->
    {callback, cwd} = options
    options = @parseOptions(options.commandArgs)
    options.cwd = cwd

    @createAtomDirectories()

    commands = []
    commands.push (callback) => @loadInstalledAtomMetadata(callback)
    commands.push (callback) => @dedupeModules(options, callback)
    async.waterfall commands, callback
