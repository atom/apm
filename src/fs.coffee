_ = require 'underscore-plus'
fs = require 'fs-plus'
ncp = require 'ncp'
rm = require 'rimraf'
wrench = require 'wrench'
path = require 'path'

fsAdditions =
  list: (directoryPath) ->
    if fs.isDirectorySync(directoryPath)
      try
        fs.readdirSync(directoryPath)
      catch e
        []
    else
      []

  listRecursive: (directoryPath) ->
    wrench.readdirSyncRecursive(directoryPath)

  cp: (sourcePath, destinationPath, callback) ->
    rm destinationPath, (error) ->
      if error?
        callback(error)
      else
        ncp(sourcePath, destinationPath, callback)

  mv: (sourcePath, destinationPath, callback) ->
    rm destinationPath, (error) ->
      if error?
        callback(error)
      else
        wrench.mkdirSyncRecursive(path.dirname(destinationPath), 0o755)
        fs.rename(sourcePath, destinationPath, callback)

module.exports = new Proxy({}, {
  get: (target, key) ->
    fsAdditions[key] or fs[key]

  set: (target, key, value) ->
    fsAdditions[key] = value
})
