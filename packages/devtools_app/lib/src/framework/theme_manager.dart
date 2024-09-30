// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:logging/logging.dart';

import '../service/editor/api_classes.dart';
import '../service/editor/editor_client.dart';
import '../shared/globals.dart';

final _log = Logger('theme_manager');

/// Manages changes in theme settings from an editor/IDE.
class EditorThemeManager extends DisposableController
    with AutoDisposeControllerMixin {
  EditorThemeManager(DartToolingDaemon dtd)
      : editorClient = DtdEditorClient(dtd);

  final DtdEditorClient editorClient;

  void listenForThemeChanges() {
    autoDisposeStreamSubscription(
      editorClient.event.listen((event) {
        if (event is ThemeChangedEvent) {
          print('received a ThemeChangedEvent');
          print(event);
          final currentTheme = getIdeTheme();
          final newTheme = event.theme;

          if (currentTheme.isDarkMode != newTheme.isDarkMode) {
            // currentTheme.isDarkMode = newTheme.isDarkMode;
            updateQueryParameter(
              IdeThemeQueryParams.devToolsThemeKey,
              currentTheme.isDarkMode
                  ? IdeThemeQueryParams.darkThemeValue
                  : IdeThemeQueryParams.lightThemeValue,
            );
          }

          if (newTheme.backgroundColor != null) {
            final newBackgroundColor =
                _tryParseColor(newTheme.backgroundColor!);
            if (newBackgroundColor != null &&
                newBackgroundColor != currentTheme.backgroundColor) {
              // currentTheme.backgroundColor = newBackgroundColor;
              updateQueryParameter(
                IdeThemeQueryParams.backgroundColorKey,
                _colorAsHex(newBackgroundColor),
              );
            }
          }

          if (newTheme.foregroundColor != null) {
            final newForegroundColor =
                _tryParseColor(newTheme.foregroundColor!);
            if (newForegroundColor != null &&
                newForegroundColor != currentTheme.foregroundColor) {
              // currentTheme.foregroundColor = newForegroundColor;
              updateQueryParameter(
                IdeThemeQueryParams.foregroundColorKey,
                _colorAsHex(newForegroundColor),
              );
            }
          }

          if (newTheme.fontSize != null &&
              newTheme.fontSize!.toDouble() != currentTheme.fontSize) {
            // currentTheme.fontSize = newTheme.fontSize!.toDouble();
            updateQueryParameter(
              IdeThemeQueryParams.fontSizeKey,
              newTheme.fontSize!.toDouble().toString(),
            );
          }

          setGlobal(IdeTheme, getIdeTheme());

          // We are toggling to the opposite theme and then back to force the IDE
          // to update all theme features.
          // TODO(https://github.com/flutter/devtools/issues/8366): Clean up so
          // that preferences controller listens for changes in all theme
          // features.
          preferences.toggleDarkModeTheme(!newTheme.isDarkMode);
          preferences.toggleDarkModeTheme(newTheme.isDarkMode);

          print('got theme changed event');
          print(currentTheme);
        }
      }),
    );
  }

  String _colorAsHex(Color color) {
    return (color.r.toInt().toRadixString(16).padLeft(2, '0') +
            color.g.toInt().toRadixString(16).padLeft(2, '0') +
            color.b.toInt().toRadixString(16).padLeft(2, '0'))
        .toUpperCase();
  }

  Color? _tryParseColor(String? input) {
    if (input == null) return null;

    try {
      return parseCssHexColor(input);
    } catch (e, st) {
      // The user can manipulate the query string so if the value is invalid
      // print the value but otherwise continue.
      _log.warning(
        'Failed to parse "$input" as a color from the querystring, ignoring: $e',
        e,
        st,
      );
      return null;
    }
  }
}
