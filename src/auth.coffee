request = require 'request'
read = require 'read'

keytar = require 'keytar'

functions =
  # Get the GitHub API token from the keychain
  #
  # * callback: A function to call with an error as the first argument and a
  #             string token as the second argument.
  getToken: (callback) ->
    if token = process.env.ATOM_ACCESS_TOKEN
      callback(null, token)
      return

    tokenName = 'GitHub Atom API Token'
    token = keytar.findPassword(tokenName)

    if error? or not token
      functions.getCredentialsFromUser (username, password) ->
        functions.makeAuthRequest {username, password}, (error, token) ->
          if token
            stored = keytar.replacePassword(tokenName, username, token)
            console.warn 'Unable to store auth token in Keychain!' unless stored

          callback(error, token)
    else
      callback(null, token)

  getCredentialsFromUser: (callback) ->
    console.log 'No GitHub credentials found, please login.'
    read prompt: "GitHub Username: ", (error, username) ->
      read prompt: "GitHub Password: ", silent: true, (error, password) ->
        callback(username.trim(), password.trim())

  getTwoFactorAuthCode: (callback) ->
    console.log 'Two-factor authentication code required.'
    read prompt: "Authentication Code: ", (error, authCode) ->
      callback(authCode.trim())

  makeAuthRequest: ({username, password, twoFactorCode}, callback) ->
    requestOptions =
      uri: 'https://api.github.com/authorizations'
      method: 'POST'
      auth:
        user: username
        password: password
        sendImmediately: true
      json:
        scopes: ['user', 'repo', 'gist']
        note: 'GitHub Atom'
        note_url: 'https://github.com/atom/atom'

    if twoFactorCode
      requestOptions.headers = 'x-github-otp': twoFactorCode

    functions.makeRequest requestOptions, (error, {headers, statusCode}, {token, message}={}) =>
      if statusCode is 201 or statusCode is 200
        if token?.length > 0
          callback(null, token)
        else
          callback('Token missing from response')
      else if statusCode is 401 and headers['x-github-otp']
        functions.getTwoFactorAuthCode (twoFactorCode) ->
          functions.makeAuthRequest {username, password, twoFactorCode}, callback
      else
        message ?= error?.message ? 'Unknown error attempting to sign in'
        callback(message)

  makeRequest: (options, callback) ->
    request(options, callback)

module.exports = functions
