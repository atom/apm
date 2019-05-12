path = require 'path'

_ = require 'underscore-plus'
yargs = require 'yargs'

config = require './apm'
Command = require './command'
Install = require './install'

module.exports =
class Rebuild extends Command
  @commandNames: ['rebuild']

  constructor: ->
    super()
    @atomNodeDirectory = path.join(config.getAtomDirectory(), '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm rebuild [<name> [<name> ...]]

      Rebuild the given modules currently installed in the node_modules folder
      in the current working directory.

      All the modules will be rebuilt if no module names are specified.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  forkNpmRebuild: (options, callback) ->
    process.stdout.write 'Rebuilding modules '

    rebuildArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'rebuild']
    rebuildArgs.push(@getNpmBuildFlags()...)
    rebuildArgs.push(options.argv._...)

    if vsArgs = @getVisualStudioFlags()
      rebuildArgs.push(vsArgs)

    fs.makeTreeSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    env.USERPROFILE = env.HOME if config.isWin32()
    @addBuildEnvVars(env)

    # node-gyp doesn't currently have an option for this so just set the
    # environment variable to bypass strict SSL
    # https://github.com/TooTallNate/node-gyp/issues/448
    useStrictSsl = @npm.config.get('strict-ssl') ? true
    env.NODE_TLS_REJECT_UNAUTHORIZED = 0 unless useStrictSsl

    # Pass through configured proxy to node-gyp
    proxy = @npm.config.get('https-proxy') or @npm.config.get('proxy') or env.HTTPS_PROXY or env.HTTP_PROXY
    rebuildArgs.push("--proxy=#{proxy}") if proxy

    @fork(@atomNpmPath, rebuildArgs, {env}, callback)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    config.loadNpm (error, @npm) =>
      @loadInstalledAtomMetadata =>
        @forkNpmRebuild options, (code, stderr='') =>
          if code is 0
            @logSuccess()
            callback()
          else
            @logFailure()
            callback(stderr)
