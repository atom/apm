@echo off
setlocal EnableDelayedExpansion
setlocal EnableExtensions

echo ^>^> Downloading bundled Node
node .\script\download-node.js

echo.
for /f "delims=" %%i in ('.\bin\node.exe -p "process.version + ' ' + process.arch"') do set bundledVersion=%%i
echo ^>^> Rebuilding apm dependencies with bundled Node !bundledVersion!
call .\bin\npm.cmd rebuild

if defined NO_APM_DEDUPE (
    echo.
    echo ^>^> Deduplication disabled
) else (
    echo.
    echo ^>^> Deduping apm dependencies
    call .\bin\npm.cmd dedupe
)