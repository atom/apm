_ = require 'underscore-plus'
fs = require 'fs-plus'
ncp = require 'ncp'
rm = require 'rimraf'
wrench = require 'wrench'

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
    fs.listTreeSync(directoryPath)

  cp: (sourcePath, destinationPath, callback) ->
    rm destinationPath, (error) ->
      if error?
        callback(error)
      else
        ncp(sourcePath, destinationPath, callback)

module.exports = new Proxy({}, {
  get: (target, key) ->
    fsAdditions[key] or fs[key]

  set: (target, key, value) ->
    fsAdditions[key] = value
})
