fs = require 'fs'
path = require 'path'
temp = require 'temp'
apm = require '../lib/apm-cli'

describe "apm init", ->
  [packagePath, themePath] = []

  beforeEach ->
    silenceOutput()
    spyOnToken()

    currentDir = temp.mkdirSync('apm-init-')
    spyOn(process, 'cwd').andReturn(currentDir)
    packagePath = path.join(currentDir, 'fake-package')
    themePath = path.join(currentDir, 'fake-theme')

  describe "when creating a package", ->
    it "generates the proper file structure", ->
      callback = jasmine.createSpy('callback')
      apm.run(['init', '--package', 'fake-package'], callback)

      waitsFor 'waiting for init to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(packagePath)).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'keymaps'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'keymaps', 'fake-package.cson'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'lib'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'lib', 'fake-package-view.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'lib', 'fake-package.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'menus'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'menus', 'fake-package.cson'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'spec', 'fake-package-view-spec.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'spec', 'fake-package-spec.coffee'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'stylesheets', 'fake-package.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(packagePath, 'package.json'))).toBeTruthy()

  describe "when creating a theme", ->
    it "generates the proper file structure", ->
      callback = jasmine.createSpy('callback')
      apm.run(['init', '--theme', 'fake-theme'], callback)

      waitsFor 'waiting for init to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(themePath)).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets', 'base.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'index.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'package.json'))).toBeTruthy()

  fdescribe "when creating an interface theme", ->
    Develop = require '../lib/develop'

    it "generates the proper file structure for dark themes", ->
      spyOn(Develop.prototype, "getRepositoryUrl").andCallFake (packageName, callback) ->
        repoUrl = path.join(__dirname, 'fixtures', 'atom-dark-ui')
        callback(null, repoUrl)

      callback = jasmine.createSpy('callback')
      apm.run(['init', '--dark-interface', 'fake-theme'], callback)

      waitsFor 'waiting for init to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(themePath)).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets', 'ui-variables.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'index.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
        packageJsonPath = path.join(themePath, 'package.json')
        expect(fs.existsSync(packageJsonPath)).toBeTruthy()
        expect(require(packageJsonPath).name).toBe 'atom-dark-ui'

    it "generates the proper file structure for light themes", ->
      Develop = require '../lib/develop'
      spyOn(Develop.prototype, "getRepositoryUrl").andCallFake (packageName, callback) ->
        repoUrl = path.join(__dirname, 'fixtures', 'atom-light-ui')
        callback(null, repoUrl)

      callback = jasmine.createSpy('callback')
      apm.run(['init', '--light-interface', 'fake-theme'], callback)

      waitsFor 'waiting for init to complete', ->
        callback.callCount is 1

      runs ->
        expect(fs.existsSync(themePath)).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'stylesheets', 'ui-variables.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'index.less'))).toBeTruthy()
        expect(fs.existsSync(path.join(themePath, 'README.md'))).toBeTruthy()
        packageJsonPath = path.join(themePath, 'package.json')
        expect(fs.existsSync(packageJsonPath)).toBeTruthy()
        expect(require(packageJsonPath).name).toBe 'atom-light-ui'
