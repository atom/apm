{spawn} = require 'child_process'
path = require 'path'
_ = require 'underscore-plus'
npm = require 'npm'
config = require './apm'
fs = require './fs'

addPortableGitToEnv = (env) ->
  localAppData = env.LOCALAPPDATA
  return unless localAppData

  githubPath = path.join(localAppData, 'GitHub')

  try
    children = fs.readdirSync(githubPath)
  catch error
    return

  for child in children when child.indexOf('PortableGit_') is 0
    cmdPath = path.join(githubPath, child, 'cmd')
    binPath = path.join(githubPath, child, 'bin')
    corePath = path.join(githubPath, child, 'mingw64', 'libexec', 'git-core')
    unless fs.isDirectorySync(corePath)
      corePath = path.join(githubPath, child, 'mingw32', 'libexec', 'git-core')
    if env.Path
      env.Path += "#{path.delimiter}#{cmdPath}#{path.delimiter}#{binPath}#{path.delimiter}#{corePath}"
    else
      env.Path = "#{cmdPath}#{path.delimiter}#{binPath}#{path.delimiter}#{corePath}"
    break

  return

addGitBashToEnv = (env) ->
  if env.ProgramFiles
    console.log('env.ProgramFiles: ' + env.ProgramFiles)
    gitPath = path.join(env.ProgramFiles, 'Git')

  console.log(gitPath, fs.isDirectorySync(gitPath))

  unless fs.isDirectorySync(gitPath)
    if env['ProgramFiles(x86)']
      gitPath = path.join(env['ProgramFiles(x86)'], 'Git')

  console.log(gitPath, fs.isDirectorySync(gitPath))

  return unless fs.isDirectorySync(gitPath)

  corePath = path.join(gitPath, 'mingw64', 'libexec', 'git-core')
  unless fs.isDirectorySync(corePath)
    corePath = path.join(gitPath, 'mingw32', 'libexec', 'git-core')

  process.stdout.write(corePath + ': ' + fs.isDirectorySync(corePath))

  cmdPath = path.join(gitPath, 'cmd')
  binPath = path.join(gitPath, 'bin')
  if env.Path
    env.Path += "#{path.delimiter}#{cmdPath}#{path.delimiter}#{binPath}#{path.delimiter}#{corePath}"
  else
    env.Path = "#{cmdPath}#{path.delimiter}#{binPath}#{path.delimiter}#{corePath}"

exports.addGitToEnv = (env) ->
  return if process.platform isnt 'win32'
  addPortableGitToEnv(env)
  addGitBashToEnv(env)

exports.getGitVersion = (callback) ->
  npmOptions =
    userconfig: config.getUserConfigPath()
    globalconfig: config.getGlobalConfigPath()
  npm.load npmOptions, ->
    git = npm.config.get('git') ? 'git'
    exports.addGitToEnv(process.env)
    spawned = spawn(git, ['--version'])
    outputChunks = []
    spawned.stderr.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.stdout.on 'data', (chunk) -> outputChunks.push(chunk)
    spawned.on 'error', ->
    spawned.on 'close', (code) ->
      if code is 0
        [gitName, versionName, version] = Buffer.concat(outputChunks).toString().split(' ')
        version = version?.trim()
      callback(version)
