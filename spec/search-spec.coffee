path = require 'path'
express = require 'express'
http = require 'http'
apm = require '../lib/apm-cli'

describe 'apm search', ->
  server = null

  beforeEach ->
    silenceOutput()
    spyOnToken()

    app = express()
    app.get '/search', (request, response) ->
      response.sendFile path.join(__dirname, 'fixtures', 'search.json')
    server = http.createServer(app)

    live = false
    server.listen 3000, '127.0.0.1', ->
      process.env.ATOM_PACKAGES_URL = "http://localhost:3000"
      live = true
    waitsFor -> live

  afterEach ->
    done = false
    server.close -> done = true
    waitsFor -> done

  it 'lists the matching packages and excludes deprecated packages', ->
    callback = jasmine.createSpy('callback')
    apm.run(['search', 'duck'], callback)

    waitsFor 'waiting for command to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.log).toHaveBeenCalled()
      expect(console.log.argsForCall[1][0]).toContain 'duckberg'
      expect(console.log.argsForCall[2][0]).toContain 'ducktales'
      expect(console.log.argsForCall[3][0]).toContain 'duckblur'
      expect(console.log.argsForCall[4][0]).toBeUndefined()

  it "logs an error if the query is missing or empty", ->
    callback = jasmine.createSpy('callback')
    apm.run(['search'], callback)

    waitsFor 'waiting for command to complete', ->
      callback.callCount > 0

    runs ->
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0
