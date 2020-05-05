path = require 'path'
express = require 'express'
fs = require 'fs-plus'
http = require 'http'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe 'apm stars', ->
  [atomHome, server] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

    app = express()
    app.get '/stars', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'available.json')
    app.get '/users/hubot/stars', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'stars.json')
    app.get '/node/v10.20.1/node-v10.20.1.tar.gz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-v10.20.1.tar.gz')
    app.get '/node/v10.20.1/node-v10.20.1-headers.tar.gz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-v10.20.1-headers.tar.gz')
    app.get '/node/v10.20.1/node.lib', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node.lib')
    app.get '/node/v10.20.1/x64/node.lib', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node_x64.lib')
    app.get '/node/v10.20.1/SHASUMS256.txt', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'SHASUMS256.txt')
    app.get '/tarball/test-module-1.2.0.tgz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'test-module-1.2.0.tgz')
    app.get '/tarball/test-module2-2.0.0.tgz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'test-module2-2.0.0.tgz')
    app.get '/packages/test-module', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'install-test-module.json')

    server =  http.createServer(app)

    live = false
    server.listen 3000, '127.0.0.1', ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_API_URL = "http://localhost:3000"
      process.env.ATOM_ELECTRON_URL = "http://localhost:3000/node"
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
      process.env.ATOM_ELECTRON_VERSION = 'v10.20.1'
      process.env.npm_config_registry = 'http://localhost:3000/'

      live = true

    waitsFor -> live

  afterEach ->
    closed = false
    server.close -> closed = true
    waitsFor -> closed

  describe "when no user flag is specified", ->
    it 'lists your starred packages', ->
      callback = jasmine.createSpy('callback')
      apm.run(['stars'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.log).toHaveBeenCalled()
        expect(console.log.argsForCall[1][0]).toContain 'beverly-hills'

  describe "when a user flag is specified", ->
    it 'lists their starred packages', ->
      callback = jasmine.createSpy('callback')
      apm.run(['stars', '--user', 'hubot'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.log).toHaveBeenCalled()
        expect(console.log.argsForCall[1][0]).toContain 'test-module'

  describe "when the install flag is specified", ->
    it "installs all of the stars", ->
      testModuleDirectory = path.join(atomHome, 'packages', 'test-module')
      expect(fs.existsSync(testModuleDirectory)).toBeFalsy()
      callback = jasmine.createSpy('callback')
      apm.run(['stars', '--user', 'hubot', '--install'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(callback.mostRecentCall.args[0]).toBeNull()
        expect(fs.existsSync(path.join(testModuleDirectory, 'index.js'))).toBeTruthy()
        expect(fs.existsSync(path.join(testModuleDirectory, 'package.json'))).toBeTruthy()

  describe 'when the theme flag is specified', ->
    it "only lists themes", ->
      callback = jasmine.createSpy('callback')
      apm.run(['stars', '--themes'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.log).toHaveBeenCalled()
        expect(console.log.argsForCall[1][0]).toContain 'duckblur'
        expect(console.log.argsForCall[1][0]).not.toContain 'beverly-hills'
