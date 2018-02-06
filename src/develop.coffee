fs = require 'fs'
path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
yargs = require 'yargs'

config = require './apm'
Command = require './command'
Install = require './install'
Link = require './link'
request = require './request'

module.exports =
class Develop extends Command
  @commandNames: ['dev', 'develop']

  constructor: ->
    @atomDirectory = config.getAtomDirectory()
    @atomDevPackagesDirectory = path.join(@atomDirectory, 'dev', 'packages')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)

    options.usage """
      Usage: apm develop <package_name> [<directory>]
             apm develop <git_remote> [<directory>]
             apm develop <github_username>/<github_project> [<directory>]
             apm dev (with any of the previous argument usage)

      Clone the given package's Git repository to the directory specified,
      install its dependencies, and link it for development to
      ~/.atom/dev/packages/<package_name>.

      If no directory is specified then the repository is cloned to
      ~/github/<package_name>. The default folder to clone packages into can
      be overridden using the ATOM_REPOS_HOME environment variable.

      Once this command completes you can open a dev window from atom using
      cmd-shift-o to run the package out of the newly cloned repository.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  getRepositoryUrl: (packageName, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}"
      json: true
    request.get requestSettings, (error, response, body={}) ->
      if error?
        callback("Request for package information failed: #{error.message}")
      else if response.statusCode is 200
        if repositoryUrl = body.repository.url
          callback(null, repositoryUrl)
        else
          callback("No repository URL found for package: #{packageName}")
      else
        message = request.getErrorMessage(response, body)
        callback("Request for package information failed: #{message}")

  installDependencies: (packageDirectory, options, callback = ->) ->
    process.chdir(packageDirectory)
    installOptions = _.clone(options)
    installOptions.callback = callback

    new Install().run(installOptions)

  linkPackage: (packageDirectory, options, callback) ->
    linkOptions = _.clone(options)
    if callback
      linkOptions.callback = callback
    linkOptions.commandArgs = [packageDirectory, '--dev']
    new Link().run(linkOptions)

  run: (options) ->
    packageName = options.commandArgs.shift()

    unless packageName?.length > 0
      return options.callback("Missing required package name")

    directory = options.commandArgs.shift()

    packageDirectory = directory ? path.join(config.getReposDirectory(), packageName)
    packageDirectory = path.resolve(packageDirectory)

    install = new Install()

    if fs.existsSync(packageDirectory)
      @linkPackage(packageDirectory, options)
    else
      startTasks = (repoUrls, packageDirectory) =>
        tasks = []
        tasks.push (callback) -> install.cloneFirstValidGitUrl repoUrls, packageDirectory, options, callback

        tasks.push (callback) => @installDependencies packageDirectory, options, callback

        tasks.push (callback) => @linkPackage packageDirectory, options, callback

        async.waterfall tasks, options.callback

      gitPackageInfo = install.getHostedGitInfo(packageName)
      if gitPackageInfo or packageName.indexOf('file://') is 0
        repoUrls = install.getNormalizedGitUrls(packageName)
        packageDirectory = directory ? path.join(config.getReposDirectory(), gitPackageInfo.project)
        packageDirectory = path.resolve(packageDirectory)
        startTasks(repoUrls, packageDirectory)
      else
      @getRepositoryUrl packageName, (error, repoUrl) ->
        if error?
          options.callback(error)
        else
          startTasks([repoUrl], packageDirectory)
