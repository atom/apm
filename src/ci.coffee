path = require 'path'
fs = require './fs'
yargs = require 'yargs'
async = require 'async'
_ = require 'underscore-plus'

config = require './apm'
Command = require './command'

module.exports =
class Ci extends Command
  @commandNames: ['ci']

  constructor: ->
    super()
    @atomDirectory = config.getAtomDirectory()
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))
    options.usage """
      Usage: apm ci

      Install a package with a clean slate.

      If you have an up-to-date package-lock.json file created by apm install,
      apm ci will install its locked contents exactly. It is substantially
      faster than apm install and produces consistently reproduceable builds,
      but cannot be used to install new packages or dependencies.
    """

    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.boolean('verbose').default('verbose', false).describe('verbose', 'Show verbose debug information')

  installModules: (options, callback) ->
    process.stdout.write 'Installing locked modules'
    if options.argv.verbose
      process.stdout.write '\n'
    else
      process.stdout.write ' '

    installArgs = [
      'ci'
      '--globalconfig', config.getGlobalConfigPath()
      '--userconfig', config.getUserConfigPath()
      @getNpmBuildFlags()...
    ]
    installArgs.push('--verbose') if options.argv.verbose

    fs.makeTreeSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @addBuildEnvVars(env)

    installOptions = {env, streaming: options.argv.verbose}

    @fork @atomNpmPath, installArgs, installOptions, (args...) =>
      @logCommandResults(callback, args...)

  run: (options) ->
    {callback} = options
    opts = @parseOptions(options.commandArgs)

    commands = []
    commands.push (callback) => config.loadNpm (error, @npm) => callback(error)
    commands.push (cb) => @loadInstalledAtomMetadata(cb)
    commands.push (cb) => @installModules(opts, cb)

    iteratee = (item, next) -> item(next)
    async.mapSeries commands, iteratee, (err) ->
      return callback(err) if err
      callback(null)
