fs = require 'fs-extra'
path = require 'path'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe 'apm command line interface', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()

  describe 'when no arguments are present', ->
    it 'prints a usage message', ->
      apm.run([])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the help flag is specified', ->
    it 'prints a usage message', ->
      apm.run(['-h'])
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0

  describe 'when the version flag is specified', ->
    it 'prints the version', ->
      callback = jasmine.createSpy('callback')
      apm.run(['-v', '--no-color'], callback)

      testAtomVersion = '0.0.0'
      tempAtomResourcePath = temp.mkdirSync('apm-resource-dir-')
      fs.writeFileSync(path.join(tempAtomResourcePath, 'package.json'), JSON.stringify(version: testAtomVersion))
      process.env.ATOM_RESOURCE_PATH = tempAtomResourcePath

      waitsFor ->
        callback.callCount is 1

      runs ->
        expect(console.error).not.toHaveBeenCalled()
        expect(console.log).toHaveBeenCalled()
        lines = console.log.argsForCall[0][0].split('\n')
        expect(lines[0]).toBe "apm  #{require('../package.json').version}"
        expect(lines[1]).toBe "npm  #{require('npm/package.json').version}"
        expect(lines[2]).toBe "node #{process.versions.node} #{process.arch}"
        expect(lines[3]).toBe "atom #{testAtomVersion}"

    describe 'when the version flag is specified and apm is unable find package.json on the resourcePath', ->
      it 'prints unknown atom version', ->
        callback = jasmine.createSpy('callback')
        apm.run(['-v', '--no-color'], callback)

        testAtomVersion = 'unknown'
        tempAtomResourcePath = temp.mkdirSync('apm-resource-dir-')
        process.env.ATOM_RESOURCE_PATH = tempAtomResourcePath

        waitsFor ->
          callback.callCount is 1

        runs ->
          expect(console.error).not.toHaveBeenCalled()
          expect(console.log).toHaveBeenCalled()
          lines = console.log.argsForCall[0][0].split('\n')
          expect(lines[3]).toBe "atom #{testAtomVersion}"

  describe 'when an unrecognized command is specified', ->
    it 'prints an error message and exits', ->
      callback = jasmine.createSpy('callback')
      apm.run(['this-will-never-be-a-command'], callback)
      expect(console.log).not.toHaveBeenCalled()
      expect(console.error).toHaveBeenCalled()
      expect(console.error.argsForCall[0][0].length).toBeGreaterThan 0
      expect(callback.mostRecentCall.args[0]).not.toBeUndefined()
