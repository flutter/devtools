// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../../devtools.dart' as devtools;
import '../../src/framework/framework_core.dart';
import '../debugger/flutter/debugger_screen.dart';
import '../info/info_controller.dart';
import '../inspector/flutter/inspector_screen.dart';
import '../logging/flutter/logging_screen.dart';
import '../memory/flutter/memory_screen.dart';
import '../network/flutter/network_screen.dart';
import '../performance/flutter/performance_screen.dart';
import '../timeline/flutter/timeline_screen.dart';
import '../ui/flutter/service_extension_widgets.dart';
import '../ui/theme.dart' as devtools_theme;
import '../version.dart';
import 'common_widgets.dart';
import 'connect_screen.dart';
import 'initializer.dart';
import 'notifications.dart';
import 'scaffold.dart';
import 'theme.dart';

// TODO(bkonyi): remove this bool when page is ready.
const showNetworkPage = false;

// TODO(https://github.com/flutter/flutter/issues/43783): Put back
// the debugger screen.
const showDebuggerPage = false;

/// Top-level configuration for the app.
@immutable
class DevToolsApp extends StatefulWidget {
  @override
  State<DevToolsApp> createState() => DevToolsAppState();

  static DevToolsAppState of(BuildContext context) {
    return context.findAncestorStateOfType<DevToolsAppState>();
  }
}

/// Initializer for the [FrameworkCore] and the app's navigation.
///
/// This manages the route generation, and marshalls URL query parameters into
/// flutter route parameters.
// TODO(https://github.com/flutter/devtools/issues/1146): Introduce tests that
// navigate the full app.
class DevToolsAppState extends State<DevToolsApp> {
  ThemeData theme;

  @override
  void initState() {
    super.initState();

    theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
  }

  /// Generates routes, separating the path from URL query parameters.
  Route _generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name);
    final path = uri.path;

    // Update the theme based on the query parameters.
    // TODO(djshuckerow): Update this with a NavigatorObserver to load the new
    // theme a frame earlier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // On desktop, don't change the theme on route changes.
      if (!kIsWeb) return;

      setState(() {
        final themeQueryParameter = uri.queryParameters['theme'];
        // We refer to the legacy theme to make sure the debugging page stays
        // in-sync with the rest of the app.
        devtools_theme.initializeTheme(themeQueryParameter);
        theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
      });
    });

    // Provide the appropriate page route.
    if (_routes.containsKey(path)) {
      WidgetBuilder builder =
          (context) => _routes[path](context, uri.queryParameters);
      assert(() {
        builder = (context) => _AlternateCheckedModeBanner(
              builder: (context) => _routes[path](
                context,
                uri.queryParameters,
              ),
            );
        return true;
      }());
      return MaterialPageRoute(settings: settings, builder: builder);
    }

    // Return a page not found.
    return MaterialPageRoute(
      settings: settings,
      builder: (BuildContext context) {
        return DevToolsScaffold.withChild(
          child: CenteredMessage('Sorry, $uri was not found.'),
        );
      },
    );
  }

  /// The routes that the app exposes.
  final Map<String, UrlParametersBuilder> _routes = {
    '/': (_, params) => Initializer(
          url: params['uri'],
          builder: (_) => DevToolsScaffold(
            tabs: const [
              InspectorScreen(),
              TimelineScreen(),
              MemoryScreen(),
              PerformanceScreen(),
              if (showDebuggerPage) DebuggerScreen(),
              if (showNetworkPage) NetworkScreen(),
              LoggingScreen(),
            ],
            actions: [
              HotReloadButton(),
              HotRestartButton(),
              DevToolsInfoAction(),
              OpenSettingsAction(),
            ],
          ),
        ),
    '/connect': (_, __) =>
        DevToolsScaffold.withChild(child: ConnectScreenBody()),
  };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => Notifications(child: child),
      onGenerateRoute: _generateRoute,
    );
  }

  /// Allow clients to force a rebuild for theme changes.
  void updateTheme() {
    setState(() {
      theme = themeFor(isDarkTheme: devtools_theme.isDarkTheme);
    });
  }
}

/// A [WidgetBuilder] that takes an additional map of URL query parameters.
typedef UrlParametersBuilder = Widget Function(
  BuildContext,
  Map<String, String>,
);

/// Displays the checked mode banner in the bottom end corner instead of the
/// top end corner.
///
/// This avoids issues with widgets in the appbar being hidden by the banner
/// in a web or desktop app.
class _AlternateCheckedModeBanner extends StatelessWidget {
  const _AlternateCheckedModeBanner({Key key, this.builder}) : super(key: key);
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    return Banner(
      message: 'DEBUG',
      textDirection: TextDirection.ltr,
      location: BannerLocation.topStart,
      child: Builder(
        builder: builder,
      ),
    );
  }
}

class DevToolsInfoAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      tooltip: 'Info',
      child: InkWell(
        onTap: () async {
          unawaited(showDialog(
            context: context,
            builder: (context) => DevToolsAboutDialog(),
          ));
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: Icon(
            Icons.info,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

class OpenSettingsAction extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ActionButton(
      tooltip: 'Settings',
      child: InkWell(
        onTap: () async {
          unawaited(showDialog(
            context: context,
            builder: (context) => const SettingsDialog(),
          ));
        },
        child: Container(
          width: DevToolsScaffold.actionWidgetSize,
          height: DevToolsScaffold.actionWidgetSize,
          alignment: Alignment.center,
          child: Icon(
            Icons.settings,
            size: actionsIconSize,
          ),
        ),
      ),
    );
  }
}

class DevToolsAboutDialog extends StatefulWidget {
  @override
  _DevToolsAboutDialogState createState() => _DevToolsAboutDialogState();
}

class _DevToolsAboutDialogState extends State<DevToolsAboutDialog> {
  FlutterVersion _flutterVersion;
  InfoController _controller;

  @override
  void initState() {
    super.initState();

    _controller = InfoController(
      onFlutterVersionChanged: (flutterVersion) {
        if (!mounted) return;
        setState(
          () {
            _flutterVersion = flutterVersion;
          },
        );
      },
    )..entering();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      actions: <Widget>[
        FlatButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop('dialog');
          },
          child: const Text('CLOSE'),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DevTools', style: textTheme.headline6),
          const PaddedDivider(
            padding: EdgeInsets.only(bottom: denseRowSpacing),
          ),
          const SelectableText('DevTools version ${devtools.version}'),
          //
          const SizedBox(height: defaultSpacing),
          Text('Connected Device Info', style: textTheme.headline6),
          const PaddedDivider(
              padding: EdgeInsets.only(bottom: denseRowSpacing)),
          _createDeviceInfo(context, textTheme, _flutterVersion),
          //
          const SizedBox(height: defaultSpacing),
          Text('Feedback', style: textTheme.headline6),
          const PaddedDivider(
            padding: EdgeInsets.only(bottom: denseRowSpacing),
          ),
          Wrap(
            children: [
              const Text('Encountered an issue? Let us know at '),
              _createFeedbackLink(context, textTheme),
              const Text('.')
            ],
          ),
        ],
      ),
    );
  }

  Widget _createDeviceInfo(
    BuildContext context,
    TextTheme textTheme,
    FlutterVersion flutterVersion,
  ) {
    if (flutterVersion == null) {
      return const Text('No Flutter device connected.');
    }

    final versions = {
      'Flutter': flutterVersion.version,
      'Framework': flutterVersion.frameworkRevision,
      'Engine': flutterVersion.engineRevision,
      'Dart': flutterVersion.dartSdkVersion,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var name in versions.keys)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: SelectableText('$name ${versions[name]}'),
          ),
      ],
    );
  }

  Widget _createFeedbackLink(BuildContext context, TextTheme textTheme) {
    return InkWell(
      onTap: () async {
        // TODO(devoncarew): Support analytics.
        // ga.select(ga.devToolsMain, ga.feedback);

        const reportIssuesUrl = 'https://github.com/flutter/devtools/issues';
        if (await url_launcher.canLaunch(reportIssuesUrl)) {
          await url_launcher.launch(reportIssuesUrl);
        } else {
          Notifications.of(context).push('Unable to open url.');
          Notifications.of(context).push('File issues at $reportIssuesUrl.');
        }
      },
      child: Text(
        'github.com/flutter/devtools/issues',
        style: textTheme.bodyText2.copyWith(
          decoration: TextDecoration.underline,
          color: devtoolsLink,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();

    super.dispose();
  }
}

// TODO(devoncarew): Add an analytics setting.

// TODO(devoncarew): Convert the SettingsDialog over to using a controller?
// Add a settings controller to Controllers that Widgets can access via
// Controllers.of(context); the SettingsController could manage setting states
// (where setting values are ValueNotifiers) and have methods to modify them.
// Widgets (like below) can then just grab the active SettingsController from
// Controller.of(context).settings and listening to its notifiers.

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    Key key,
  }) : super(key: key);

  @override
  _SettingsDialogState createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    void _toggleTheme([bool value]) {
      value ??= !devtools_theme.isDarkTheme;
      setState(() {
        devtools_theme.useDarkTheme = value;

        DevToolsApp.of(context).updateTheme();
      });
    }

    return AlertDialog(
      title: const Text('Settings'),
      actions: <Widget>[
        FlatButton(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop('dialog');
          },
          child: const Text('CLOSE'),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Theme setting
          InkWell(
            onTap: _toggleTheme,
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: devtools_theme.isDarkTheme,
                  onChanged: (bool value) => _toggleTheme(value),
                ),
                const Text('Use a dark theme'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
