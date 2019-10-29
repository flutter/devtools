// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

ThemeData themeFor({@required bool isDarkTheme}) {
  final theme = isDarkTheme ? _darkTheme() : _lightTheme();
  print(theme);
  return theme;
}

ThemeData _darkTheme() {
  return ThemeData.dark().copyWith(
    primaryColor: devtoolsGrey[900],
    primaryColorDark: devtoolsBlue[700],
    primaryColorLight: devtoolsBlue[400],
    indicatorColor: devtoolsBlue[400],
    accentColor: devtoolsBlue[400],
    backgroundColor: devtoolsGrey[600],
  );
}

ThemeData _lightTheme() {
  return ThemeData.light().copyWith(
    primaryColor: devtoolsBlue[600],
    primaryColorDark: devtoolsBlue[700],
    primaryColorLight: devtoolsBlue[400],
    indicatorColor: Colors.yellowAccent[400],
    accentColor: devtoolsBlue[400],
  );
}

const devtoolsGrey = ColorSwatch<int>(900, {
  900: Color(0xFF202124),
  600: Color(0xFF60646B),
  100: Color(0xFFD5D7Da),
});

const devtoolsYellow = ColorSwatch<int>(700, {
  700: Color(0xFFFFC108),
});

const devtoolsBlue = ColorSwatch<int>(600, {
  700: Color(0xFF02569B),
  600: Color(0xFF0175C2),
  400: Color(0xFF13B9FD),
});

class ThemeObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route previousRoute) {
    didUpdateRoute(route, previousRoute);
  }

  @override
  void didPop(Route route, Route previousRoute) {
    didUpdateRoute(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route previousRoute) {
    didUpdateRoute(route, previousRoute);
  }

  @override
  void didReplace({Route newRoute, Route oldRoute}) {
    didUpdateRoute(newRoute, oldRoute);
  }

  void didUpdateRoute(Route route, Route previousRoute) {
    final previousUri = Uri.parse(previousRoute.settings.name);
    final newUri = Uri.parse(route.settings.name);
    if (previousUri.queryParameters.containsKey('theme') &&
        !newUri.queryParameters.containsKey('theme')) {
      final newQueryParams = Map.of(newUri.queryParameters);
      newQueryParams['theme'] = previousUri.queryParameters['theme'];
      newUri.replace(queryParameters: newQueryParams);
      route.settings.copyWith(name: newUri.toString());
    }
  }
}
