path = require 'path'
fs = require 'fs-plus'
temp = require 'temp'
apm = require '../lib/apm-cli'

createPackage = (packageName, includeDev=false) ->
  atomHome = temp.mkdirSync('apm-home-dir-')
  packagePath = path.join(atomHome, 'packages', packageName)
  fs.makeTreeSync(path.join(packagePath, 'lib'))
  fs.writeFileSync(path.join(packagePath, 'package.json'), "{}")
  if includeDev
    devPackagePath = path.join(atomHome, 'dev', 'packages', packageName)
    fs.makeTreeSync(path.join(devPackagePath, 'lib'))
    fs.writeFileSync(path.join(devPackagePath, 'package.json'), "{}")
  process.env.ATOM_HOME = atomHome
  return {packagePath, devPackagePath}

describe 'apm uninstall', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()
    process.env.ATOM_API_URL = 'http://localhost:5432'

  describe 'when no package is specified', ->
    it 'logs an error and exits', ->
      callback = jasmine.createSpy('callback')
      apm.run(['uninstall'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).not.toBeUndefined()

  describe 'when the package is not installed', ->
    it 'ignores the package', ->
      callback = jasmine.createSpy('callback')
      apm.run(['uninstall', 'a-package-that-does-not-exist'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.error.callCount).toBe 1

  describe 'when the package is installed', ->
    it 'deletes the package', ->
      {packagePath} = createPackage('test-package')

      expect(fs.existsSync(packagePath)).toBeTruthy()
      callback = jasmine.createSpy('callback')
      apm.run(['uninstall', 'test-package'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(packagePath)).toBeFalsy()

  describe 'when the package folder exists but does not contain a package.json', ->
    it 'does not delete the folder', ->
      {packagePath} = createPackage('test-package')
      fs.unlinkSync(path.join(packagePath, 'package.json'))

      callback = jasmine.createSpy('callback')
      apm.run(['uninstall', 'test-package'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(packagePath)).toBeTruthy()

    describe 'when . is specified as the package name', ->
      it 'resolves to the basename of the cwd', ->
        {packagePath} = createPackage('test-package')

        expect(fs.existsSync(packagePath)).toBeTruthy()

        oldCwd = process.cwd()
        process.chdir(packagePath)

        callback = jasmine.createSpy('callback')
        apm.run(['uninstall', '.'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(packagePath)).toBeFalsy()
          process.chdir(oldCwd)

    describe "--dev", ->
      it "deletes the packages from the dev packages folder", ->
        {packagePath, devPackagePath} = createPackage('test-package', true)

        expect(fs.existsSync(packagePath)).toBeTruthy()
        callback = jasmine.createSpy('callback')
        apm.run(['uninstall', 'test-package', '--dev'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(devPackagePath)).toBeFalsy()
          expect(fs.existsSync(packagePath)).toBeTruthy()

    describe "--hard", ->
      it "deletes the packages from the both packages folders", ->
        atomHome = temp.mkdirSync('apm-home-dir-')
        packagePath = path.join(atomHome, 'packages', 'test-package')
        fs.makeTreeSync(path.join(packagePath, 'lib'))
        fs.writeFileSync(path.join(packagePath, 'package.json'), "{}")
        devPackagePath = path.join(atomHome, 'dev', 'packages', 'test-package')
        fs.makeTreeSync(path.join(devPackagePath, 'lib'))
        fs.writeFileSync(path.join(devPackagePath, 'package.json'), "{}")
        process.env.ATOM_HOME = atomHome

        expect(fs.existsSync(packagePath)).toBeTruthy()
        callback = jasmine.createSpy('callback')
        apm.run(['uninstall', 'test-package', '--hard'], callback)

        waitsFor 'waiting for command to complete', ->
          callback.callCount > 0

        runs ->
          expect(fs.existsSync(devPackagePath)).toBeFalsy()
          expect(fs.existsSync(packagePath)).toBeFalsy()
