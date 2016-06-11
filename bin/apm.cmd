@echo off
setlocal

set maybe_node_gyp_path=%~dp0\..\node_modules\node-gyp\bin\node-gyp.js
if exist %maybe_node_gyp_path% (
  set npm_config_node_gyp=%maybe_node_gyp_path%
)

if exist "%~dp0\node.exe" (
  "%~dp0\node.exe" "%~dp0/../lib/cli.js" %*
) else (
  node.exe "%~dp0/../lib/cli.js" %*
)
