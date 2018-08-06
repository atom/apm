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
  @commandNames: ['clean']

  constructor: ->
    super()
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  getDependencies: (modulePath, allDependencies) ->
    try
      {dependencies, packageDependencies} = CSON.readFileSync(CSON.resolve(path.join(modulePath, 'package'))) ? {}
    catch error
      return

    _.extend(allDependencies, dependencies)

    modulesPath = path.join(modulePath, 'node_modules')
    for installedModule in fs.list(modulesPath) when installedModule isnt '.bin'
      @getDependencies(path.join(modulesPath, installedModule), allDependencies)

  getModulesToRemove: ->
    packagePath = CSON.resolve('package')
    return [] unless packagePath

    {devDependencies, dependencies, packageDependencies} = CSON.readFileSync(packagePath) ? {}
    devDependencies ?= {}
    dependencies ?= {}
    packageDependencies ?= {}

    modulesToRemove = []
    modulesPath = path.resolve('node_modules')
    modulePathFilter = (modulePath) ->
      modulePath isnt '.bin' and modulePath isnt 'atom-package-manager'
    installedModules = fs.list(modulesPath).filter modulePathFilter

    # Check if the module is a scoped module (starting with an '@')
    # If so, recursively lookup inside this directory
    # and concatenate to the root folder
    #
    # e.g. if you have a dependency @types/atom, modulePath === @types
    # fs.list(@types) === ['atom'], thus this will return ['@types/atom']
    #
    # At the end, flat map, since these scoped packages can return more than 1
    # and normal modules return only 1
    filteredInstalledModules = [].concat.apply([], installedModules.map (modulePath) ->
      if not (modulePath.substring(0, 1) is '@')
        [modulePath]
      else
        fs.list(path.join(modulesPath, modulePath)).filter modulePathFilter
          .map (subPath) ->
            path.join(modulePath, subPath)
    )

    # Find all dependencies of all installed modules recursively
    for installedModule in filteredInstalledModules
      @getDependencies(path.join(modulesPath, installedModule), dependencies)

    # Only remove dependencies that aren't referenced by any installed modules
    for installedModule in filteredInstalledModules
      continue if dependencies.hasOwnProperty(installedModule)
      continue if devDependencies.hasOwnProperty(installedModule)
      continue if packageDependencies.hasOwnProperty(installedModule)
      modulesToRemove.push(installedModule)

    modulesToRemove

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)

    options.usage """
      Usage: apm clean

      Deletes all packages in the node_modules folder that are not referenced
      as a dependency in the package.json file.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  removeModule: (module, callback) ->
    process.stdout.write("Removing #{module} ")
    @fork @atomNpmPath, ['uninstall', module], (args...) =>
      @logCommandResults(callback, args...)

  run: (options) ->
    uninstallCommands = []
    @getModulesToRemove().forEach (module) =>
      uninstallCommands.push (callback) => @removeModule(module, callback)

    if uninstallCommands.length > 0
      doneCallback = (error) =>
        if error?
          options.callback(error)
        else
          @run(options)
    else
      doneCallback = options.callback
    async.waterfall(uninstallCommands, doneCallback)
