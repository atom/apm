path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
express = require 'express'
http = require 'http'
wrench = require 'wrench'
apm = require '../lib/apm-cli'

describe 'apm clean', ->
  [moduleDirectory, server] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

    app = express()

    app.get '/node/v0.10.3/node-v0.10.3.tar.gz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node-v0.10.3.tar.gz')
    app.get '/node/v0.10.3/node.lib', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node.lib')
    app.get '/node/v0.10.3/x64/node.lib', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'node_x64.lib')
    app.get '/node/v0.10.3/SHASUMS256.txt', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'SHASUMS256.txt')
    app.get '/test-module', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'install-test-module.json')
    app.get '/tarball/test-module-1.2.0.tgz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'test-module-1.2.0.tgz')

    server = http.createServer(app)

    live = false
    server.listen 3000, '127.0.0.1', ->
      console.log "Server started"
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      process.env.ATOM_ELECTRON_URL = "http://localhost:3000/node"
      process.env.ATOM_ELECTRON_VERSION = 'v0.10.3'
      process.env.npm_config_registry = 'http://localhost:3000/'

      moduleDirectory = path.join(temp.mkdirSync('apm-test-module-'), 'test-module-with-dependencies')
      wrench.copyDirSyncRecursive(path.join(__dirname, 'fixtures', 'test-module-with-dependencies'), moduleDirectory)
      process.chdir(moduleDirectory)
      live = true
    waitsFor -> live

  afterEach ->
    done = false
    server.close -> done = true
    waitsFor -> done

  it 'uninstalls any packages not referenced in the package.json', ->
    removedPath = path.join(moduleDirectory, 'node_modules', 'will-be-removed')
    fs.makeTreeSync(removedPath)
    fs.writeFileSync(
      path.join(removedPath, 'package.json'),
      '{"name": "will-be-removed", "version": "1.0.0", "dependencies": {}}',
      'utf8'
    )

    callback = jasmine.createSpy('callback')
    apm.run(['clean'], callback)

    waitsFor 'waiting for command to complete', ->
      callback.callCount > 0

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeUndefined()
      expect(fs.existsSync(removedPath)).toBeFalsy()

  it 'uninstalls a scoped package', ->
    removedPath = path.join(moduleDirectory, 'node_modules/@types/atom')
    fs.makeTreeSync(removedPath)
    fs.writeFileSync(
      path.join(removedPath, 'package.json'),
      '{"name": "@types/atom", "version": "1.0.0", "dependencies": {}}',
      'utf8'
    )

    callback = jasmine.createSpy('callback')
    apm.run(['clean'], callback)

    waitsFor 'waiting for command to complete', ->
      callback.callCount > 0

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeUndefined()
      expect(fs.existsSync(removedPath)).toBeFalsy()
