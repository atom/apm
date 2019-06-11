@echo off
setlocal EnableDelayedExpansion

set "PATH=%~dp0;%PATH%"

:: Force npm to use its builtin node-gyp
set npm_config_node_gyp=

"%~dp0\..\node_modules\.bin\npm.cmd" %*
