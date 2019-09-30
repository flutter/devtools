import 'package:flutter/material.dart';

import 'connect_page.dart';

/// Top-level configuration for the app.
@immutable
class Config {
  /// The routes the navigator in the app will use.
  final Map<String, WidgetBuilder> routes = <String, WidgetBuilder>{
    '/': (context) => ConnectPage(),
  };
}
