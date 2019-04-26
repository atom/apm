path = require 'path'
fs = require 'fs-extra'
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
    @atomNodeGypPath = process.env.ATOM_NODE_GYP_PATH or require.resolve('npm/node_modules/node-gyp/bin/node-gyp')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
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

  installDependencies: (options, callback) =>
    async.waterfall [
      (cb) => @installNode(options, cb)
      (cb) => @installModules(options, cb)
    ], callback

  installNode: (options, callback) =>
    installNodeArgs = ['install']
    installNodeArgs.push(@getNpmBuildFlags()...)
    installNodeArgs.push("--ensure")
    installNodeArgs.push("--verbose") if options.argv.verbose

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    env.USERPROFILE = env.HOME if config.isWin32()

    fs.mkdirpSync(@atomDirectory)

    # node-gyp doesn't currently have an option for this so just set the
    # environment variable to bypass strict SSL
    # https://github.com/TooTallNate/node-gyp/issues/448
    useStrictSsl = @npm.config.get('strict-ssl') ? true
    env.NODE_TLS_REJECT_UNAUTHORIZED = 0 unless useStrictSsl

    # Pass through configured proxy to node-gyp
    proxy = @npm.config.get('https-proxy') or @npm.config.get('proxy') or env.HTTPS_PROXY or env.HTTP_PROXY
    installNodeArgs.push("--proxy=#{proxy}") if proxy

    opts = {env, cwd: @atomDirectory, streaming: options.argv.verbose}

    @fork @atomNodeGypPath, installNodeArgs, opts, (code, stderr='', stdout='') ->
      if code is 0
        callback()
      else
        callback("#{stdout}\n#{stderr}")

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

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @updateWindowsEnv(env) if config.isWin32()
    @addNodeBinToEnv(env)
    @addProxyToEnv(env)
    installOptions = {env, streaming: options.argv.verbose}

    @fork @atomNpmPath, installArgs, installOptions, (args...) =>
      @logCommandResults(callback, args...)

  run: (options) ->
    {callback} = options
    opts = @parseOptions(options.commandArgs)

    commands = []
    commands.push (callback) => config.loadNpm (error, @npm) => callback(error)
    commands.push (cb) => @loadInstalledAtomMetadata(cb)
    commands.push (cb) => @installDependencies(opts, cb)

    iteratee = (item, next) -> item(next)
    async.mapSeries commands, iteratee, (err) ->
      return callback(err) if err
      callback(null)
