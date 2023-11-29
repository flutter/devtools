@echo off

IF DEFINED DEVTOOLS_TOOL_FLUTTER_FROM_PATH (
	echo Running devtools_tool using Dart/Flutter from PATH because DEVTOOLS_TOOL_FLUTTER_FROM_PATH is set
	dart run %~dp0/devtools_tool.dart %*
) ELSE (
	%~dp0/../flutter-sdk/bin/dart run %~dp0/devtools_tool.dart %*
)

EXIT /B %errorlevel%
