@echo off

pushd "%~dp0"
dart run ./devtools_tool.dart %*

IF %errorlevel% NEQ 0 GOTO :error

popd
EXIT /B 0

:error
popd
EXIT /B %errorlevel%

