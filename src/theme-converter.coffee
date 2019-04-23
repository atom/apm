fs = require 'fs-extra'
path = require 'path'
url = require 'url'
request = require './request'
TextMateTheme = require './text-mate-theme'

# Convert a TextMate theme to an Atom theme
module.exports =
class ThemeConverter
  constructor: (@sourcePath, destinationPath) ->
    @destinationPath = path.resolve(destinationPath)

  readTheme: (callback) ->
    {protocol} = url.parse(@sourcePath)
    if protocol is 'http:' or protocol is 'https:'
      requestOptions = url: @sourcePath
      request.get requestOptions, (error, response, body) =>
        if error?
          if error.code is 'ENOTFOUND'
            error = "Could not resolve URL: #{@sourcePath}"
          callback(error)
        else  if response.statusCode isnt 200
          callback("Request to #{@sourcePath} failed (#{response.headers.status})")
        else
          callback(null, body)
    else
      sourcePath = path.resolve(@sourcePath)
      try
        if fs.statSync(sourcePath).isFile()
          callback(null, fs.readFileSync(sourcePath, 'utf8'))
          return

      # Not a file, or we errored
      callback("TextMate theme file not found: #{sourcePath}")

  convert: (callback) ->
    @readTheme (error, themeContents) =>
      return callback(error) if error?

      try
        theme = new TextMateTheme(themeContents)
      catch error
        return callback(error)

      stylesPath = path.join(@destinationPath, 'styles')
      fs.mkdirpSync(stylesPath)
      fs.writeFileSync(path.join(stylesPath, 'base.less'), theme.getStylesheet())
      fs.writeFileSync(path.join(stylesPath, 'syntax-variables.less'), theme.getSyntaxVariables())
      callback()
