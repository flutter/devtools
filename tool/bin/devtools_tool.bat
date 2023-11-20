@echo off

%~dp0/../flutter-sdk/bin/dart run %~dp0/devtools_tool.dart %*

EXIT /B %errorlevel%
