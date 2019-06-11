@echo off
setlocal EnableDelayedExpansion

set "PATH=%~dp0;%PATH%"
"%~dp0\..\node_modules\.bin\npm.cmd" %*
