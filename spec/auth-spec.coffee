keytar = require 'keytar'
auth = require '../lib/auth'

describe 'auth', ->

  spyOnGetCreds = (username='thedude', password='password') ->
    spyOn(auth, 'getCredentialsFromUser').andCallFake (callback) -> callback(username, password)

  spyOnGetTwoFactor = (token='token') ->
    spyOn(auth, 'getTwoFactorAuthCode').andCallFake (callback) -> callback(token)

  spyOnRequest = (returnVal) ->
    spyOn(auth, 'makeRequest').andCallFake (options, callback) -> callback(returnVal)

  spyOnKeytar: (token, replaceTokenReturn=true) ->
    spyOn(keytar, 'findPassword').andReturn(token)
    spyOn(keytar, 'replacePassword').andReturn(replaceTokenReturn)

  beforeEach ->
    silenceOutput()

  describe 'single factor auth', ->
    describe 'when no token found', ->
      beforeEach ->
        spyOnKeytar(null)

      it 'can authenticate', ->
        spyOnGetCreds()

        callback = jasmine.createSpy('callback')
        apm.run(['available'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(console.log).toHaveBeenCalled()
          expect(console.log.argsForCall[1][0]).toContain 'beverly-hills@9.0.2.1.0'
