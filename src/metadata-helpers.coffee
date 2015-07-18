isTheme = (metadata) ->
  return false unless metadata? and (metadata.theme? or metadata.type?)
  metadata.theme or metadata.type is 'syntax-theme' or metadata.type is 'ui-theme'

isPackageSet = (metadata) ->
  metadata?.type is 'package-set'

isPackage = (metadata) ->
  not (isTheme(metadata) or isPackageSet(metadata))

module.exports = {isTheme, isPackageSet, isPackage}
