assert = require 'assert'
fs = require 'fs-extra'
path = require 'path'

_ = require 'underscore-plus'
async = require 'async'
CSON = require 'season'
yargs = require 'yargs'
Git = require 'git-utils'
klawSync = require 'klaw-sync'
semver = require 'semver'
temp = require 'temp'
hostedGitInfo = require 'hosted-git-info'

config = require './apm'
Command = require './command'
RebuildModuleCache = require './rebuild-module-cache'
request = require './request'
{isDeprecatedPackage} = require './deprecated-packages'

module.exports =
class Install extends Command
  @commandNames: ['install', 'i']

  constructor: ->
    super()
    @atomDirectory = config.getAtomDirectory()
    @atomPackagesDirectory = path.join(@atomDirectory, 'packages')
    @atomNodeDirectory = path.join(@atomDirectory, '.node-gyp')
    @atomNpmPath = require.resolve('npm/bin/npm-cli')
    @repoLocalPackagePathRegex = /^file:(?!\/\/)(.*)/

  parseOptions: (argv) ->
    options = yargs(argv).wrap(Math.min(100, yargs.terminalWidth()))
    options.usage """

      Usage: apm install [<package_name>...]
             apm install <package_name>@<package_version>
             apm install <git_remote>
             apm install <github_username>/<github_project>
             apm install --packages-file my-packages.txt
             apm i (with any of the previous argument usage)

      Install the given Atom package to ~/.atom/packages/<package_name>.

      If no package name is given then all the dependencies in the package.json
      file are installed to the node_modules folder in the current working
      directory.

      A packages file can be specified that is a newline separated list of
      package names to install with optional versions using the
      `package-name@version` syntax.
    """
    options.alias('c', 'compatible').string('compatible').describe('compatible', 'Only install packages/themes compatible with this Atom version')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('s', 'silent').boolean('silent').describe('silent', 'Set the npm log level to silent')
    options.alias('q', 'quiet').boolean('quiet').describe('quiet', 'Set the npm log level to warn')
    options.boolean('check').describe('check', 'Check that native build tools are installed')
    options.boolean('verbose').default('verbose', false).describe('verbose', 'Show verbose debug information')
    options.string('packages-file').describe('packages-file', 'A text file containing the packages to install')
    options.boolean('production').describe('production', 'Do not install dev dependencies')

  installModule: (options, pack, moduleURI, callback) ->
    installGlobally = options.installGlobally ? true

    installArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(moduleURI)
    installArgs.push(@getNpmBuildFlags()...)
    installArgs.push("--global-style") if installGlobally
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--quiet') if options.argv.quiet
    installArgs.push('--production') if options.argv.production

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    fs.mkdirpSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @addBuildEnvVars(env)

    installOptions = {env}
    installOptions.streaming = true if @verbose

    if installGlobally
      installDirectory = temp.mkdirSync('apm-install-dir-')
      nodeModulesDirectory = path.join(installDirectory, 'node_modules')
      fs.mkdirpSync(nodeModulesDirectory)
      installOptions.cwd = installDirectory

    @fork @atomNpmPath, installArgs, installOptions, (code, stderr='', stdout='') =>
      if code is 0
        if installGlobally
          commands = []
          children = fs.readdirSync(nodeModulesDirectory).filter (dir) -> dir isnt ".bin"
          assert.equal(children.length, 1, "Expected there to only be one child in node_modules")
          child = children[0]
          source = path.join(nodeModulesDirectory, child)
          destination = path.join(@atomPackagesDirectory, child)
          commands.push (next) ->
            # emptyDir will pass `destination` as the first callback argument if it doesn't exist
            # We expect the first argument to always be the next callback function,
            # so don't call emptyDir unless `destination` exists
            if fs.existsSync(destination)
              fs.emptyDir(destination, next)
            else
              next()
          commands.push (next) -> fs.copy(source, destination, next)
          commands.push (next) => @buildModuleCache(pack.name, next)
          commands.push (next) => @warmCompileCache(pack.name, next)

          async.waterfall commands, (error) =>
            if error?
              @logFailure()
            else
              @logSuccess() unless options.argv.json
            callback(error, {name: child, installPath: destination})
        else
          callback(null, {name: child, installPath: destination})
      else
        if installGlobally
          fs.removeSync(installDirectory)
          @logFailure()

        error = "#{stdout}\n#{stderr}"
        error = @getGitErrorMessage(pack) if error.indexOf('code ENOGIT') isnt -1
        callback(error)

  getGitErrorMessage: (pack) ->
    message = """
      Failed to install #{pack.name} because Git was not found.

      The #{pack.name} package has module dependencies that cannot be installed without Git.

      You need to install Git and add it to your path environment variable in order to install this package.

    """

    switch process.platform
      when 'win32'
        message += """

          You can install Git by downloading, installing, and launching GitHub for Windows: https://windows.github.com

        """
      when 'linux'
        message += """

          You can install Git from your OS package manager.

        """

    message += """

      Run apm -v after installing Git to see what version has been detected.
    """

    message

  installModules: (options, callback) =>
    process.stdout.write 'Installing modules ' unless options.argv.json

    @forkInstallCommand options, (args...) =>
      if options.argv.json
        @logCommandResultsIfFail(callback, args...)
      else
        @logCommandResults(callback, args...)

  forkInstallCommand: (options, callback) ->
    installArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'install']
    installArgs.push(@getNpmBuildFlags()...)
    installArgs.push('--silent') if options.argv.silent
    installArgs.push('--quiet') if options.argv.quiet
    installArgs.push('--production') if options.argv.production

    if vsArgs = @getVisualStudioFlags()
      installArgs.push(vsArgs)

    fs.mkdirpSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @addBuildEnvVars(env)

    installOptions = {env}
    installOptions.cwd = options.cwd if options.cwd
    installOptions.streaming = true if @verbose

    @fork(@atomNpmPath, installArgs, installOptions, callback)

  # Request package information from the atom.io API for a given package name.
  #
  # packageName - The string name of the package to request.
  # callback - The function to invoke when the request completes with an error
  #            as the first argument and an object as the second.
  requestPackage: (packageName, callback) ->
    requestSettings =
      url: "#{config.getAtomPackagesUrl()}/#{packageName}"
      json: true
      retries: 4
    request.get requestSettings, (error, response, body={}) ->
      if error?
        message = "Request for package information failed: #{error.message}"
        message += " (#{error.code})" if error.code
        callback(message)
      else if response.statusCode isnt 200
        message = request.getErrorMessage(response, body)
        callback("Request for package information failed: #{message}")
      else
        if body.releases.latest
          callback(null, body)
        else
          callback("No releases available for #{packageName}")

  # Is the package at the specified version already installed?
  #
  #  * packageName: The string name of the package.
  #  * packageVersion: The string version of the package.
  isPackageInstalled: (packageName, packageVersion) ->
    try
      {version} = CSON.readFileSync(CSON.resolve(path.join('node_modules', packageName, 'package'))) ? {}
      packageVersion is version
    catch error
      false

  # Install the package with the given name and optional version
  #
  # metadata - The package metadata object with at least a name key. A version
  #            key is also supported. The version defaults to the latest if
  #            unspecified.
  # options - The installation options object.
  # callback - The function to invoke when installation completes with an
  #            error as the first argument.
  installRegisteredPackage: (metadata, options, callback) ->
    packageName = metadata.name
    packageVersion = metadata.version

    installGlobally = options.installGlobally ? true
    unless installGlobally
      if packageVersion and @isPackageInstalled(packageName, packageVersion)
        callback(null, {})
        return

    label = packageName
    label += "@#{packageVersion}" if packageVersion
    unless options.argv.json
      process.stdout.write "Installing #{label} "
      if installGlobally
        process.stdout.write "to #{@atomPackagesDirectory} "

    @requestPackage packageName, (error, pack) =>
      if error?
        @logFailure()
        callback(error)
      else
        packageVersion ?= @getLatestCompatibleVersion(pack)
        unless packageVersion
          @logFailure()
          callback("No available version compatible with the installed Atom version: #{@installedAtomVersion}")
          return

        {tarball} = pack.versions[packageVersion]?.dist ? {}
        unless tarball
          @logFailure()
          callback("Package version: #{packageVersion} not found")
          return

        commands = []
        commands.push (next) => @installModule(options, pack, tarball, next)
        if installGlobally and (packageName.localeCompare(pack.name, 'en', {sensitivity: 'accent'}) isnt 0)
          commands.push (newPack, next) => # package was renamed; delete old package folder
            fs.removeSync(path.join(@atomPackagesDirectory, packageName))
            next(null, newPack)
        commands.push ({installPath}, next) ->
          if installPath?
            metadata = JSON.parse(fs.readFileSync(path.join(installPath, 'package.json'), 'utf8'))
            json = {installPath, metadata}
            next(null, json)
          else
            next(null, {}) # installed locally, no install path data

        async.waterfall commands, (error, json) =>
          unless installGlobally
            if error?
              @logFailure()
            else
              @logSuccess() unless options.argv.json
          callback(error, json)

  # Install the package with the given name and local path
  #
  # packageName - The name of the package
  # packagePath - The local path of the package in the form "file:./packages/package-name"
  # options     - The installation options object.
  # callback    - The function to invoke when installation completes with an
  #               error as the first argument.
  installLocalPackage: (packageName, packagePath, options, callback) ->
    unless options.argv.json
      process.stdout.write "Installing #{packageName} from #{packagePath.slice('file:'.length)} "
      commands = []
      commands.push (next) =>
        @installModule(options, {name: packageName}, packagePath, next)
      commands.push ({installPath}, next) ->
        if installPath?
          metadata = JSON.parse(fs.readFileSync(path.join(installPath, 'package.json'), 'utf8'))
          json = {installPath, metadata}
          next(null, json)
        else
          next(null, {}) # installed locally, no install path data

      async.waterfall commands, (error, json) =>
        if error?
          @logFailure()
        else
          @logSuccess() unless options.argv.json
        callback(error, json)

  # Install all the package dependencies found in the package.json file.
  #
  # options - The installation options
  # callback - The callback function to invoke when done with an error as the
  #            first argument.
  installPackageDependencies: (options, callback) ->
    options = _.extend({}, options, installGlobally: false)
    commands = []
    for name, version of @getPackageDependencies()
      do (name, version) =>
        commands.push (next) =>
          if @repoLocalPackagePathRegex.test(version)
            @installLocalPackage(name, version, options, next)
          else
            @installRegisteredPackage({name, version}, options, next)

    async.series(commands, callback)

  installDependencies: (options, callback) ->
    options.installGlobally = false
    commands = []
    commands.push (callback) => @installModules(options, callback)
    commands.push (callback) => @installPackageDependencies(options, callback)

    async.waterfall commands, callback

  # Get all package dependency names and versions from the package.json file.
  getPackageDependencies: ->
    try
      metadata = fs.readFileSync('package.json', 'utf8')
      {packageDependencies, dependencies} = JSON.parse(metadata) ? {}

      return {} unless packageDependencies
      return packageDependencies unless dependencies

      # This code filters out any `packageDependencies` that have an equivalent
      # normalized repo-local package path entry in the `dependencies` section of
      # `package.json`.  Versioned `packageDependencies` are always returned.
      filteredPackages = {}
      for packageName, packageSpec of packageDependencies
        dependencyPath = @getRepoLocalPackagePath(dependencies[packageName])
        packageDependencyPath = @getRepoLocalPackagePath(packageSpec)
        unless packageDependencyPath and dependencyPath is packageDependencyPath
          filteredPackages[packageName] = packageSpec

      filteredPackages
    catch error
      {}

  getRepoLocalPackagePath: (packageSpec) ->
    return undefined if not packageSpec
    repoLocalPackageMatch = packageSpec.match(@repoLocalPackagePathRegex)
    if repoLocalPackageMatch
      path.normalize(repoLocalPackageMatch[1])
    else
      undefined

  createAtomDirectories: ->
    fs.mkdirpSync(@atomDirectory)
    fs.mkdirpSync(@atomPackagesDirectory)
    fs.mkdirpSync(@atomNodeDirectory)

  # Compile a sample native module to see if a useable native build toolchain
  # is instlalled and successfully detected. This will include both Python
  # and a compiler.
  checkNativeBuildTools: (callback) ->
    process.stdout.write 'Checking for native build tools '

    buildArgs = ['--globalconfig', config.getGlobalConfigPath(), '--userconfig', config.getUserConfigPath(), 'build']
    buildArgs.push(path.resolve(__dirname, '..', 'native-module'))
    buildArgs.push(@getNpmBuildFlags()...)

    if vsArgs = @getVisualStudioFlags()
      buildArgs.push(vsArgs)

    fs.mkdirpSync(@atomDirectory)

    env = _.extend({}, process.env, {HOME: @atomNodeDirectory, RUSTUP_HOME: config.getRustupHomeDirPath()})
    @addBuildEnvVars(env)

    buildOptions = {env}
    buildOptions.streaming = true if @verbose

    fs.removeSync(path.resolve(__dirname, '..', 'native-module', 'build'))

    @fork @atomNpmPath, buildArgs, buildOptions, (args...) =>
      @logCommandResults(callback, args...)

  packageNamesFromPath: (filePath) ->
    filePath = path.resolve(filePath)

    isFile = false
    try
      isFile = fs.statSync(filePath).isFile()

    unless isFile
      throw new Error("File '#{filePath}' does not exist")

    packages = fs.readFileSync(filePath, 'utf8')
    @sanitizePackageNames(packages.split(/\s/))

  buildModuleCache: (packageName, callback) ->
    packageDirectory = path.join(@atomPackagesDirectory, packageName)
    rebuildCacheCommand = new RebuildModuleCache()
    rebuildCacheCommand.rebuild packageDirectory, ->
      # Ignore cache errors and just finish the install
      callback()

  warmCompileCache: (packageName, callback) ->
    packageDirectory = path.join(@atomPackagesDirectory, packageName)

    @getResourcePath (resourcePath) =>
      try
        CompileCache = require(path.join(resourcePath, 'src', 'compile-cache'))

        isntNodeModules = ({path: directoryPath}) ->
          path.basename(directoryPath) isnt 'node_modules'

        for {path: childPath, stats} in klawSync(packageDirectory, {filter: isntNodeModules})
          if stats.isFile()
            try
              CompileCache.addPathToCache(childPath, @atomDirectory)
      callback(null)

  isBundledPackage: (packageName, callback) ->
    @getResourcePath (resourcePath) ->
      try
        atomMetadata = JSON.parse(fs.readFileSync(path.join(resourcePath, 'package.json')))
      catch error
        return callback(false)

      callback(atomMetadata?.packageDependencies?.hasOwnProperty(packageName))

  getLatestCompatibleVersion: (pack) ->
    unless @installedAtomVersion
      if isDeprecatedPackage(pack.name, pack.releases.latest)
        return null
      else
        return pack.releases.latest

    latestVersion = null
    for version, metadata of pack.versions ? {}
      continue unless semver.valid(version)
      continue unless metadata
      continue if isDeprecatedPackage(pack.name, version)

      engine = metadata.engines?.atom ? '*'
      continue unless semver.validRange(engine)
      continue unless semver.satisfies(@installedAtomVersion, engine)

      latestVersion ?= version
      latestVersion = version if semver.gt(version, latestVersion)

    latestVersion

  getHostedGitInfo: (name) ->
    hostedGitInfo.fromUrl(name)

  installGitPackage: (packageUrl, options, callback) ->
    tasks = []

    cloneDir = temp.mkdirSync("atom-git-package-clone-")

    tasks.push (data, next) =>
      urls = @getNormalizedGitUrls(packageUrl)
      @cloneFirstValidGitUrl urls, cloneDir, options, (err) ->
        next(err, data)

    tasks.push (data, next) =>
      @installGitPackageDependencies cloneDir, options, (err) ->
        next(err, data)

    tasks.push (data, next) =>
      @getRepositoryHeadSha cloneDir, (err, sha) ->
        data.sha = sha
        next(err, data)

    tasks.push (data, next) ->
      metadataFilePath = CSON.resolve(path.join(cloneDir, 'package'))
      CSON.readFile metadataFilePath, (err, metadata) ->
        data.metadataFilePath = metadataFilePath
        data.metadata = metadata
        next(err, data)

    tasks.push (data, next) ->
      data.metadata.apmInstallSource =
        type: "git"
        source: packageUrl
        sha: data.sha
      CSON.writeFile data.metadataFilePath, data.metadata, (err) ->
        next(err, data)

    tasks.push (data, next) =>
      {name} = data.metadata
      targetDir = path.join(@atomPackagesDirectory, name)
      process.stdout.write "Moving #{name} to #{targetDir} " unless options.argv.json
      fs.emptyDir targetDir, (err) =>
        if err
          next(err)
        else
          fs.copy cloneDir, targetDir, (err) =>
            if err
              next(err)
            else
              @logSuccess() unless options.argv.json
              json = {installPath: targetDir, metadata: data.metadata}
              next(null, json)

    iteratee = (currentData, task, next) -> task(currentData, next)
    async.reduce tasks, {}, iteratee, callback

  getNormalizedGitUrls: (packageUrl) ->
    packageInfo = @getHostedGitInfo(packageUrl)

    if packageUrl.indexOf('file://') is 0
      [packageUrl]
    else if packageInfo.default is 'sshurl'
      [packageInfo.toString()]
    else if packageInfo.default is 'https'
      [packageInfo.https().replace(/^git\+https:/, "https:")]
    else if packageInfo.default is 'shortcut'
      [
        packageInfo.https().replace(/^git\+https:/, "https:"),
        packageInfo.sshurl()
      ]

  cloneFirstValidGitUrl: (urls, cloneDir, options, callback) ->
    async.detectSeries urls, (url, next) =>
      @cloneNormalizedUrl url, cloneDir, options, (error) ->
        next(not error)
    , (result) ->
      if not result
        invalidUrls = "Couldn't clone #{urls.join(' or ')}"
        invalidUrlsError = new Error(invalidUrls)
        callback(invalidUrlsError)
      else
        callback()

  cloneNormalizedUrl: (url, cloneDir, options, callback) ->
    # Require here to avoid circular dependency
    Develop = require './develop'
    develop = new Develop()

    develop.cloneRepository url, cloneDir, options, (err) ->
      callback(err)

  installGitPackageDependencies: (directory, options, callback) =>
    options.cwd = directory
    @installDependencies(options, callback)

  getRepositoryHeadSha: (repoDir, callback) ->
    try
      repo = Git.open(repoDir)
      sha = repo.getReferenceTarget("HEAD")
      callback(null, sha)
    catch err
      callback(err)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)
    packagesFilePath = options.argv['packages-file']

    @createAtomDirectories()

    if options.argv.check
      config.loadNpm (error, @npm) =>
        @loadInstalledAtomMetadata =>
          @checkNativeBuildTools(callback)
      return

    @verbose = options.argv.verbose
    if @verbose
      request.debug(true)
      process.env.NODE_DEBUG = 'request'

    installPackage = (name, nextInstallStep) =>
      gitPackageInfo = @getHostedGitInfo(name)

      if gitPackageInfo or name.indexOf('file://') is 0
        @installGitPackage name, options, nextInstallStep
      else if name is '.'
        @installDependencies(options, nextInstallStep)
      else # is registered package
        atIndex = name.indexOf('@')
        if atIndex > 0
          version = name.substring(atIndex + 1)
          name = name.substring(0, atIndex)

        @isBundledPackage name, (isBundledPackage) =>
          if isBundledPackage
            console.error """
              The #{name} package is bundled with Atom and should not be explicitly installed.
              You can run `apm uninstall #{name}` to uninstall it and then the version bundled
              with Atom will be used.
            """.yellow
          @installRegisteredPackage({name, version}, options, nextInstallStep)

    if packagesFilePath
      try
        packageNames = @packageNamesFromPath(packagesFilePath)
      catch error
        return callback(error)
    else
      packageNames = @packageNamesFromArgv(options.argv)
      packageNames.push('.') if packageNames.length is 0

    commands = []
    commands.push (callback) => config.loadNpm (error, @npm) => callback(error)
    commands.push (callback) => @loadInstalledAtomMetadata -> callback()
    packageNames.forEach (packageName) ->
      commands.push (callback) -> installPackage(packageName, callback)
    iteratee = (item, next) -> item(next)
    async.mapSeries commands, iteratee, (err, installedPackagesInfo) ->
      return callback(err) if err
      installedPackagesInfo = _.compact(installedPackagesInfo)
      installedPackagesInfo = installedPackagesInfo.filter (item, idx) ->
        packageNames[idx] isnt "."
      console.log(JSON.stringify(installedPackagesInfo, null, "  ")) if options.argv.json
      callback(null)
