try
  keytar = require 'keytar'
catch error
  # Gracefully handle keytar failing to load due to missing library on Linux
  if process.platform is 'linux'
    keytar =
      findPassword: -> Promise.reject()
      setPassword: -> Promise.reject()
  else
    throw error

tokenName = 'Atom.io API Token'

module.exports =
  # Get the Atom.io API token from the keychain.
  #
  # callback - A function to call with an error as the first argument and a
  #            string token as the second argument.
  getToken: (callback) ->
    keytar.findPassword(tokenName)
      .then (token) ->
        if token
          callback(null, token)
        else
          Promise.reject()
      .catch ->
        if token = process.env.ATOM_ACCESS_TOKEN
          callback(null, token)
        else
          callback """
            No Atom.io API token in keychain
            Run `apm login` or set the `ATOM_ACCESS_TOKEN` environment variable.
          """

  # Save the given token to the keychain.
  #
  # token - A string token to save.
  saveToken: (token) ->
    keytar.setPassword(tokenName, 'atom.io', token)
