// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:ui';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:dtd/dtd.dart';
import 'package:logging/logging.dart';

import '../shared/config_specific/post_message/post_message.dart';
import '../shared/editor/api_classes.dart';
import '../shared/globals.dart';

final _log = Logger('theme_manager');

/// Manages changes in theme settings from an editor/IDE.
class EditorThemeManager extends DisposableController
    with AutoDisposeControllerMixin {
  EditorThemeManager(this.dtd);

  final DartToolingDaemon dtd;

  void listenForThemeChanges() async {
    await dtd.streamListen(editorStreamName).catchError((error) {
      _log.warning(error);
    });

    autoDisposeStreamSubscription(
      dtd.onEvent(editorStreamName).listen((event) {
        if (EditorEventKind.values.asNameMap()[event.kind] ==
            EditorEventKind.themeChanged) {
          try {
            final newTheme = ThemeChangedEvent.fromJson(event.data).theme;
            _updateTheme(newTheme);
          } catch (e) {
            _log.warning('Failed to parse/update theme: $e');
          }
        }
      }),
    );

    // Handle themeChanged from postMessage.
    autoDisposeStreamSubscription(
      onPostMessage.listen((event) {
        if (event.data case {
          'method': 'editor.themeChanged',
          'params': {'theme': final Map themeJson},
        }) {
          try {
            _updateTheme(
              EditorTheme.fromJson(themeJson.cast<String, Object?>()),
            );
          } catch (e) {
            _log.warning('Failed to parse/update theme: $e');
          }
        }
      }),
    );
  }

  void _updateTheme(EditorTheme newTheme) {
    final currentTheme = getIdeTheme();
    if (currentTheme.isDarkMode != newTheme.isDarkMode) {
      updateQueryParameter(
        IdeThemeQueryParams.devToolsThemeKey,
        newTheme.isDarkMode
            ? IdeThemeQueryParams.darkThemeValue
            : IdeThemeQueryParams.lightThemeValue,
      );
    }

    if (newTheme.backgroundColor != null) {
      final newBackgroundColor = tryParseColor(
        newTheme.backgroundColor!,
        logger: _log,
      );
      if (newBackgroundColor != null &&
          newBackgroundColor != currentTheme.backgroundColor) {
        updateQueryParameter(
          IdeThemeQueryParams.backgroundColorKey,
          _colorAsHex(newBackgroundColor),
        );
      }
    }

    if (newTheme.foregroundColor != null) {
      final newForegroundColor = tryParseColor(
        newTheme.foregroundColor!,
        logger: _log,
      );
      if (newForegroundColor != null &&
          newForegroundColor != currentTheme.foregroundColor) {
        updateQueryParameter(
          IdeThemeQueryParams.foregroundColorKey,
          _colorAsHex(newForegroundColor),
        );
      }
    }

    if (newTheme.fontSize != null &&
        newTheme.fontSize!.toDouble() != currentTheme.fontSize) {
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
  }

  String _colorAsHex(Color color) {
    return ((color.r * 255).round().toRadixString(16).padLeft(2, '0') +
            (color.g * 255).round().toRadixString(16).padLeft(2, '0') +
            (color.b * 255).round().toRadixString(16).padLeft(2, '0'))
        .toUpperCase();
  }
}
