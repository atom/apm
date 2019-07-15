fs = require 'fs'
path = require 'path'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe 'apm link/unlink', ->
  beforeEach ->
    silenceOutput()
    spyOnToken()

  describe "when the dev flag is false (the default)", ->
    it 'symlinks packages to $ATOM_HOME/packages', ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      packageToLink = temp.mkdirSync('a-package-')
      process.chdir(packageToLink)
      callback = jasmine.createSpy('callback')

      runs ->
        apm.run(['link'], callback)

      waitsFor 'waiting for link to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBeTruthy()
        expect(fs.realpathSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBe fs.realpathSync(packageToLink)

        callback.reset()
        apm.run(['unlink'], callback)

      waitsFor 'waiting for unlink to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBeFalsy()

  describe "when the dev flag is true", ->
    it 'symlinks packages to $ATOM_HOME/dev/packages', ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      packageToLink = temp.mkdirSync('a-package-')
      process.chdir(packageToLink)
      callback = jasmine.createSpy('callback')

      runs ->
        apm.run(['link', '--dev'], callback)

      waitsFor 'waiting for link to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBeTruthy()
        expect(fs.realpathSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBe fs.realpathSync(packageToLink)

        callback.reset()
        apm.run(['unlink', '--dev'], callback)

      waitsFor 'waiting for unlink to complete', ->
        callback.callCount > 0

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBeFalsy()

  describe "when the hard flag is true", ->
    it "unlinks the package from both $ATOM_HOME/packages and $ATOM_HOME/dev/packages", ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      packageToLink = temp.mkdirSync('a-package-')
      process.chdir(packageToLink)
      callback = jasmine.createSpy('callback')

      runs ->
        apm.run(['link', '--dev'], callback)

      waitsFor 'link --dev to complete', ->
        callback.callCount is 1

      runs ->
        apm.run(['link'], callback)

      waitsFor 'link to complete', ->
        callback.callCount is 2

      runs ->
        apm.run(['unlink', '--hard'], callback)

      waitsFor 'unlink --hard to complete', ->
        callback.callCount is 3

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink)))).toBeFalsy()
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink)))).toBeFalsy()

  describe "when the all flag is true", ->
    it "unlinks all packages in $ATOM_HOME/packages and $ATOM_HOME/dev/packages", ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      packageToLink1 = temp.mkdirSync('a-package-')
      packageToLink2 = temp.mkdirSync('a-package-')
      packageToLink3 = temp.mkdirSync('a-package-')
      callback = jasmine.createSpy('callback')

      runs ->
        apm.run(['link', '--dev', packageToLink1], callback)

      waitsFor 'link --dev to complete', ->
        callback.callCount is 1

      runs ->
        callback.reset()
        apm.run(['link', packageToLink2], callback)
        apm.run(['link', packageToLink3], callback)

      waitsFor 'link to complee', ->
        callback.callCount is 2

      runs ->
        callback.reset()
        expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink1)))).toBeTruthy()
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink2)))).toBeTruthy()
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink3)))).toBeTruthy()
        apm.run(['unlink', '--all'], callback)

      waitsFor 'unlink --all to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'dev', 'packages', path.basename(packageToLink1)))).toBeFalsy()
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink2)))).toBeFalsy()
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(packageToLink3)))).toBeFalsy()

  describe "when the package name is numeric", ->
    it "still links and unlinks normally", ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      numericPackageName = temp.mkdirSync('42')
      callback = jasmine.createSpy('callback')

      runs ->
        apm.run(['link', numericPackageName], callback)

      waitsFor 'link to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(numericPackageName)))).toBeTruthy()
        expect(fs.realpathSync(path.join(atomHome, 'packages', path.basename(numericPackageName)))).toBe fs.realpathSync(numericPackageName)

        callback.reset()
        apm.run(['unlink', numericPackageName], callback)

      waitsFor 'unlink to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', path.basename(numericPackageName)))).toBeFalsy()

  describe "when the package name is set after --name", ->
    it "still links and unlinks normally", ->
      atomHome = temp.mkdirSync('apm-home-dir-')
      process.env.ATOM_HOME = atomHome
      packagePath = temp.mkdirSync('new-package')
      packageName = 'new-package-name'
      callback = jasmine.createSpy('callback')

      runs ->
        apm.run(['link', packagePath, '--name', packageName], callback)

      waitsFor 'link to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', packageName))).toBeTruthy()
        expect(fs.realpathSync(path.join(atomHome, 'packages', packageName))).toBe fs.realpathSync(packagePath)

        callback.reset()
        apm.run(['unlink', packageName], callback)

      waitsFor 'unlink to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(path.join(atomHome, 'packages', packageName))).toBeFalsy()

  describe "when unlinking a path that is not a symbolic link", ->
    it "logs an error and exits", ->
      callback = jasmine.createSpy('callback')
      process.chdir(temp.mkdirSync('not-a-symlink'))
      apm.run(['unlink'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).not.toBeUndefined()

  describe "when unlinking a path that does not exist", ->
    it "logs an error and exits", ->
      callback = jasmine.createSpy('callback')
      apm.run(['unlink', 'a-path-that-does-not-exist'], callback)

      waitsFor 'waiting for command to complete', ->
        callback.callCount > 0

      runs ->
        expect(console.error.mostRecentCall.args[0].length).toBeGreaterThan 0
        expect(callback.mostRecentCall.args[0]).not.toBeUndefined()
