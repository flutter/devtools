REM Copyright 2025 The Flutter Authors
REM Use of this source code is governed by a BSD-style license that can be
REM found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.
@echo off

IF DEFINED DEVTOOLS_TOOL_FLUTTER_FROM_PATH (
	echo Running dt using Dart/Flutter from PATH because DEVTOOLS_TOOL_FLUTTER_FROM_PATH is set
	dart run %~dp0/dt.dart %*
) ELSE (

	rem If the `devtools/tool/flutter-sdk` directory does not exist yet, use whatever Dart
	rem is on the user's path to update it before proceeding.
	IF NOT EXIST "%~dp0/../flutter-sdk/" (
		echo Running dt using the Dart SDK from `where.exe dart` to create the Flutter SDK in tool/flutter-sdk.
  		dart run %~dp0/dt.dart update-flutter-sdk
	)

	%~dp0/../flutter-sdk/bin/dart run %~dp0/dt.dart %*
)

EXIT /B %errorlevel%
