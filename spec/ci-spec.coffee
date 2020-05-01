path = require 'path'
fs = require 'fs'
http = require 'http'
temp = require 'temp'
express = require 'express'
wrench = require 'wrench'
CSON = require 'season'
apm = require '../lib/apm-cli'

describe 'apm ci', ->
  [atomHome, resourcePath, server] = []

  beforeEach ->
    spyOnToken()
    silenceOutput()

    atomHome = temp.mkdirSync 'apm-home-dir-'
    process.env.ATOM_HOME = atomHome

    resourcePath = temp.mkdirSync('atom-resource-path-')
    process.env.ATOM_RESOURCE_PATH = resourcePath

    delete process.env.npm_config_cache

    app = express()
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
    app.get '/test-module-with-dependencies', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'install-locked-version.json')
    app.get '/test-module', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'install-test-module.json')
    app.get '/native-module', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'native-module.json')
    app.get '/tarball/test-module-with-dependencies-1.1.0.tgz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'test-module-with-dependencies-1.1.0.tgz')
    app.get '/tarball/test-module-1.1.0.tgz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'test-module-1.1.0.tgz')
    app.get '/tarball/native-module-1.0.0.tgz', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'native-module-1.0.0.tgz')

    server = http.createServer(app)

    live = false
    server.listen 3000, '127.0.0.1', ->
      process.env.ATOM_ELECTRON_URL = "http://localhost:3000/node"
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000/packages"
      process.env.ATOM_ELECTRON_VERSION = 'v10.20.1'
      process.env.npm_config_registry = 'http://localhost:3000/'
      live = true
    waitsFor -> live

  afterEach ->
    done = false
    server.close -> done = true
    waitsFor -> done

  it 'installs dependency versions as specified by the lockfile', ->
    moduleDirectory = path.join temp.mkdirSync('apm-test-'), 'test-module-with-lockfile'
    wrench.copyDirSyncRecursive path.join(__dirname, 'fixtures', 'test-module-with-lockfile'), moduleDirectory
    process.chdir moduleDirectory

    callback = jasmine.createSpy('callback')
    apm.run(['ci'], callback)
    waitsFor 'waiting for install to complete', 600000, -> callback.callCount > 0

    runs ->
      expect(callback.mostRecentCall.args[0]).toBeNull()

      pjson0 = CSON.readFileSync path.join('node_modules', 'test-module-with-dependencies', 'package.json')
      expect(pjson0.version).toBe('1.1.0')

      pjson1 = CSON.readFileSync path.join('node_modules', 'test-module', 'package.json')
      expect(pjson1.version).toBe('1.1.0')

  it 'builds a native dependency correctly', ->
    moduleDirectory = path.join temp.mkdirSync('apm-test-'), 'test-module-with-native'
    wrench.copyDirSyncRecursive path.join(__dirname, 'fixtures', 'test-module-with-lockfile'), moduleDirectory
    process.chdir moduleDirectory

    pjsonPath = path.join moduleDirectory, 'package.json'
    pjson = CSON.readFileSync pjsonPath
    pjson.dependencies['native-module'] = '^1.0.0'
    CSON.writeFileSync pjsonPath, pjson

    callback0 = jasmine.createSpy('callback')
    callback1 = jasmine.createSpy('callback')

    apm.run(['install'], callback0)
    waitsFor 'waiting for install to complete', 600000, -> callback0.callCount > 0

    runs ->
      expect(callback0.mostRecentCall.args[0]).toBeNull()
      apm.run(['ci'], callback1)

    waitsFor 'waiting for ci to complete', 600000, -> callback1.callCount > 0

    runs ->
      expect(callback1.mostRecentCall.args[0]).toBeNull()
      expect(fs.existsSync(
        path.join(moduleDirectory, 'node_modules', 'native-module', 'build', 'Release', 'native.node')
      )).toBeTruthy()

  it 'fails if the lockfile is not present', ->
    moduleDirectory = path.join temp.mkdirSync('apm-test-'), 'test-module'
    wrench.copyDirSyncRecursive path.join(__dirname, 'fixtures', 'test-module'), moduleDirectory
    process.chdir moduleDirectory

    callback = jasmine.createSpy('callback')
    apm.run(['ci'], callback)
    waitsFor 'waiting for install to complete', 600000, -> callback.callCount > 0

    runs ->
      expect(callback.mostRecentCall.args[0]).not.toBeNull()

  it 'fails if the lockfile is out of date', ->
    moduleDirectory = path.join temp.mkdirSync('apm-test-'), 'test-module-with-lockfile'
    wrench.copyDirSyncRecursive path.join(__dirname, 'fixtures', 'test-module-with-lockfile'), moduleDirectory
    process.chdir moduleDirectory

    pjsonPath = path.join moduleDirectory, 'package.json'
    pjson = CSON.readFileSync pjsonPath
    pjson.dependencies['test-module'] = '^1.2.0'
    CSON.writeFileSync pjsonPath, pjson

    callback = jasmine.createSpy('callback')
    apm.run(['ci'], callback)
    waitsFor 'waiting for install to complete', 600000, -> callback.callCount > 0

    runs ->
      expect(callback.mostRecentCall.args[0]).not.toBeNull()
