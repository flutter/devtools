@echo off

IF DEFINED DEVTOOLS_TOOL_FLUTTER_FROM_PATH (
	echo Running devtools_tool using Dart/Flutter from PATH because DEVTOOLS_TOOL_FLUTTER_FROM_PATH is set
	dart run %~dp0/devtools_tool.dart %*
) ELSE (

	rem If the `devtools/tool/flutter-sdk` directory does not exist yet, use whatever Dart
	rem is on the user's path to update it before proceeding.
	IF NOT EXIST "%~dp0/../flutter-sdk/" (
		echo Running devtools_tool using the Dart SDK from `where.exe dart` to create the Flutter SDK in tool/flutter-sdk.
  		dart run %~dp0/devtools_tool.dart update-flutter-sdk
	)

	%~dp0/../flutter-sdk/bin/dart run %~dp0/devtools_tool.dart %*
)

EXIT /B %errorlevel%
