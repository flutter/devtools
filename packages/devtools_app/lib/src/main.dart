// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:pedantic/pedantic.dart';
import 'package:vm_service/vm_service.dart';

import 'config_specific/logger/logger.dart';
import 'core/message_bus.dart';
import 'debugger/html_debugger_screen.dart';
import 'framework/html_framework.dart';
import 'framework_controller.dart';
import 'globals.dart';
import 'info/html_info_screen.dart';
import 'inspector/html_inspector_screen.dart';
import 'logging/html_logging_screen.dart';
import 'memory/html_memory_screen.dart';
import 'model/html_model.dart';
import 'performance/html_performance_screen.dart';
import 'server_api_client.dart';
import 'service_registrations.dart' as registrations;
import 'timeline/html_timeline_controller.dart';
import 'timeline/html_timeline_screen.dart';
import 'ui/analytics.dart' as ga;
import 'ui/analytics_platform.dart' as ga_platform;
import 'ui/html_custom.dart';
import 'ui/html_elements.dart';
import 'ui/icons.dart';
import 'ui/primer.dart';
import 'ui/ui_utils.dart';
import 'utils.dart';

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';

class HtmlPerfToolFramework extends HtmlFramework {
  HtmlPerfToolFramework() {
    html.window.onError.listen(_gAReportExceptions);

    initDevToolsServerConnection();
    initGlobalUI();
    initTestingModel();
  }

  void _gAReportExceptions(html.Event e) {
    final html.ErrorEvent errorEvent = e as html.ErrorEvent;

    final message = '${errorEvent.message}\n'
        '${errorEvent.filename}@${errorEvent.lineno}:${errorEvent.colno}\n'
        '${errorEvent.error}';

    // Report exceptions with DevTools to GA.
    ga.error(message, true);

    // Also log them to the console to aid debugging.
    log(message, LogLevel.error);
  }

  HtmlStatusItem isolateSelectStatus;
  PSelect isolateSelect;

  HtmlStatusItem connectionStatus;
  HtmlStatus reloadStatus;

  static const _reloadActionId = 'reload-action';
  static const _restartActionId = 'restart-action';

  DevToolsServerConnection devToolsServer;

  void initGlobalUI() async {
    // Listen for clicks on the 'send feedback' button.
    queryId('send-feedback-button').onClick.listen((_) {
      ga.select(ga.devToolsMain, ga.feedback);
      // TODO(devoncarew): Fill in useful product info here, like the Flutter
      // SDK version and the version of DevTools in use.
      html.window
          .open('https://github.com/flutter/devtools/issues', '_feedback');
    });

    // Listen for clicks on the 'Try DevTools on Flutter Web' button.
    queryId('try-flutter-web-devtools')
      ..hidden = false
      ..onClick.listen((_) {
        var href = '/flutter.html#/';
        // Preserve query parameters when opening the Flutter demo so the
        // user does not need to go through the connect dialog again.
        final flutterQueryParams =
            Uri.tryParse(html.window.location.href).queryParameters ?? {};
        if (flutterQueryParams.isNotEmpty) {
          href += Uri(queryParameters: flutterQueryParams).toString();
        }
        html.window.location.href = href;
      });

    await serviceManager.serviceAvailable.future;
    await addScreens();
    screensReady.complete();

    final mainNav = CoreElement.from(queryId('main-nav'))..clear();
    final iconNav = CoreElement.from(queryId('icon-nav'))..clear();

    for (HtmlScreen screen in screens) {
      final link = CoreElement('a')
        ..add(<CoreElement>[
          span(c: 'octicon ${screen.iconClass}'),
          span(text: ' ${screen.name}', c: 'optional-1140')
        ]);
      if (screen.disabled) {
        link
          ..onClick.listen((html.MouseEvent e) {
            e.preventDefault();
            toast(link.tooltip);
          })
          ..toggleClass('disabled', true)
          ..tooltip = screen.disabledTooltip;
      } else {
        link
          ..attributes['href'] = screen.ref
          ..onClick.listen((html.MouseEvent e) {
            e.preventDefault();
            navigateTo(screen.id);
          });
      }
      (screen.showTab ? mainNav : iconNav).add(link);
    }

    isolateSelectStatus = HtmlStatusItem();
    globalStatus.add(isolateSelectStatus);
    isolateSelect = PSelect()
      ..small()
      ..change(_handleIsolateSelect);
    isolateSelectStatus.element.add(isolateSelect);
    _rebuildIsolateSelect();

    serviceManager.isolateManager.onIsolateCreated
        .listen(_rebuildIsolateSelect);
    serviceManager.isolateManager.onIsolateExited.listen(_rebuildIsolateSelect);
    serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(_rebuildIsolateSelect);

    _initHotReloadRestartServiceListeners();

    serviceManager.onStateChange.listen((_) {
      _rebuildConnectionStatus();

      if (!serviceManager.hasConnection) {
        toast('Device connection lost.');
      }
    });
  }

  void initTestingModel() {
    final app = HtmlApp.register(this);
    screensReady.future.then(app.devToolsReady);
  }

  Future initDevToolsServerConnection() async {
    // When running the debug DDC Build, the server won't be running so we
    // can't connect to its API (for now at least, the API is optional).
    if (isDebugBuild()) {
      return;
    }

    DevToolsServerConnection devToolsServer;

    try {
      devToolsServer = await DevToolsServerConnection.connect();
    } catch (e) {
      print('Failed to connect to SSE API: $e');
      return;
    }

    // If we showed a notification for DevTools and the user manually clicked
    // into the window instead, we should hide the notification automatically.
    html.window.onFocus.listen((_) => devToolsServer.dismissNotifications());

    // TODO(dantup): As a workaround for not being able to reconnect DevTools to
    // a new VM yet (https://github.com/flutter/devtools/issues/989) we reload
    // the page and pass a querystring variable to know that we need to notify
    // the user.
    final uri = Uri.parse(html.window.location.href);
    if (uri.queryParameters.containsKey('notify')) {
      final newParams = Map.of(uri.queryParameters)..remove('notify');
      html.window.history.pushState(
          null, null, uri.replace(queryParameters: newParams).toString());
      unawaited(devToolsServer.notify());
    }

    // Handle onShowPageId.
    frameworkController.onShowPageId.listen((String pageId) {
      final screen = getScreen(pageId);
      if (screen != null) {
        load(screen);
      }
    });

    // Handle onConnectVmEvent.
    frameworkController.onConnectVmEvent.listen((ConnectVmEvent event) {
      // Reload the page with the new VM service URI in the querystring.
      // TODO(dantup): Remove this code and replace with code that just reconnects
      // (and optionally notifies based on requestParams['notify']) when it's
      // supported better (https://github.com/flutter/devtools/issues/989).
      //
      // This currently doesn't currently work, as the app does not reinitialize
      // correctly:
      //
      //   _framework.connectDialog.connectTo(Uri.parse(requestParams['uri']));
      //   if (requestParams['notify'] == true) {
      //     this.notify();
      //   }
      final uri = Uri.parse(html.window.location.href);
      final newUriParams = Map.of(uri.queryParameters);
      newUriParams['uri'] = event.serviceProtocolUri.toString();
      if (event.notify) {
        newUriParams['notify'] = 'true';
      }
      html.window.location
          .replace(uri.replace(queryParameters: newUriParams).toString());
    });

    // Send notifyPageChange.
    onPageChange.listen((pageId) {
      frameworkController.notifyPageChange(pageId);
    });
  }

  void disableAppWithError(String title, [dynamic error]) {
    html.document
        .getElementById('header')
        .children
        .removeWhere((e) => e.id != 'title');
    html.document.getElementById('content').children.clear();
    showError(title, error);
  }

  Future<void> addScreens() async {
    // The types of platforms we support are:
    //   Dart CLI apps
    //   Dart web apps
    //   Flutter VM apps, in debug and profile modes
    //   Flutter web apps, using package:flutter_web
    //   Flutter web apps, using package:flutter (the unforked code)

    final app = serviceManager.connectedApp;

    final isDartWebApp = await app.isDartWebApp;
    final isFlutterApp = await app.isFlutterApp;
    final isDartCliApp = await app.isDartCliApp;
    final isFlutterVmApp = isFlutterApp && !isDartWebApp;
    final isFlutterVmProfileBuild =
        isFlutterVmApp && (await app.isProfileBuild);
    final isFlutterWebApp = isFlutterApp && isDartWebApp;

    const notRunningFlutterMsg =
        'This screen is disabled because you are not running a Flutter '
        'application';
    const runningProfileBuildMsg =
        'This screen is disabled because you are running a profile build of '
        'your application';
    const notFlutterWebMsg = 'This screen does not work with Flutter web apps';
    const notDartWebMsg = 'This screen does not work with Dart web apps';
    const duplicateDebuggerFunctionalityMsg =
        'This screen is disabled because it provides functionality already '
        'available in your code editor';

    // Collect all platform information flutter, web, chrome, versions, etc. for
    // possible GA collection.
    ga_platform.setupDimensions();

    addScreen(HtmlInspectorScreen(
      enabled: isFlutterApp && !isFlutterVmProfileBuild,
      disabledTooltip: isFlutterVmProfileBuild
          ? runningProfileBuildMsg
          : notRunningFlutterMsg,
    ));
    addScreen(HtmlTimelineScreen(
      isDartCliApp ? TimelineMode.full : TimelineMode.frameBased,
      enabled: app.isRunningOnDartVM,
      disabledTooltip:
          isFlutterWebApp ? notFlutterWebMsg : notRunningFlutterMsg,
    ));
    addScreen(HtmlMemoryScreen(
      enabled: isFlutterVmApp || isDartCliApp,
      disabledTooltip: isFlutterWebApp ? notFlutterWebMsg : notDartWebMsg,
      isProfileBuild: isFlutterVmProfileBuild,
    ));
    addScreen(HtmlPerformanceScreen(
      enabled: isFlutterVmApp || isDartCliApp,
      disabledTooltip: isFlutterWebApp ? notFlutterWebMsg : notDartWebMsg,
    ));
    addScreen(HtmlDebuggerScreen(
        enabled: !isFlutterVmProfileBuild && !isTabDisabledByQuery('debugger'),
        disabledTooltip: isFlutterVmProfileBuild
            ? runningProfileBuildMsg
            : duplicateDebuggerFunctionalityMsg));
    addScreen(HtmlLoggingScreen());
    addScreen(HtmlInfoScreen());
  }

  IsolateRef get currentIsolate =>
      serviceManager.isolateManager.selectedIsolate;

  void _handleIsolateSelect() {
    serviceManager.isolateManager.selectIsolate(isolateSelect.value);
  }

  void _rebuildIsolateSelect([IsolateRef _]) {
    isolateSelect.clear();
    for (IsolateRef ref in serviceManager.isolateManager.isolates) {
      isolateSelect.option(isolateName(ref), value: ref.id);
    }
    isolateSelect.disabled = serviceManager.isolateManager.isolates.isEmpty;
    if (serviceManager.isolateManager.selectedIsolate != null) {
      isolateSelect.selectedIndex = serviceManager.isolateManager.isolates
          .indexOf(serviceManager.isolateManager.selectedIsolate);
    }
  }

  void _initHotReloadRestartServiceListeners() {
    final hotReloadListenable = serviceManager
        .registeredServiceListenable(registrations.hotReload.service);
    hotReloadListenable.addListener(() {
      final reloadServiceAvailable = hotReloadListenable.value;
      if (reloadServiceAvailable) {
        _buildReloadButton();
      } else {
        removeGlobalAction(_reloadActionId);
      }
    });

    final hotRestartListenable = serviceManager
        .registeredServiceListenable(registrations.hotReload.service);
    hotRestartListenable.addListener(() {
      final restartServiceAvailable = hotRestartListenable.value;
      if (restartServiceAvailable) {
        _buildRestartButton();
      } else {
        removeGlobalAction(_restartActionId);
      }
    });
  }

  void _buildReloadButton() async {
    // TODO(devoncarew): We currently create hot reload events when hot reload
    // is initialed, and react to those events in the UI. Going forward, we'll
    // want to instead have flutter_tools fire hot reload events, and react to
    // them in the UI. That will mean that our UI will update appropriately
    // even when other clients (the CLI, and IDE) initiate the hot reload.

    final HtmlActionButton reloadAction = HtmlActionButton(
      _reloadActionId,
      FlutterIcons.hotReloadWhite,
      'Hot Reload',
    );
    reloadAction.click(() async {
      // Hide any previous status related to / restart.
      reloadStatus?.dispose();

      final HtmlStatus status = HtmlStatus(auxiliaryStatus, 'reloading...');
      reloadStatus = status;

      final Stopwatch timer = Stopwatch()..start();

      try {
        reloadAction.disabled = true;
        await serviceManager.performHotReload();
        messageBus.addEvent(BusEvent('reload.start'));
        timer.stop();
        // 'reloaded in 600ms'
        final String message = 'reloaded in ${_renderDuration(timer.elapsed)}';
        messageBus.addEvent(BusEvent('reload.end', data: message));
        status.setText(message);

        ga.select(ga.devToolsMain, ga.hotReload, timer.elapsed.inMilliseconds);
      } catch (_) {
        const String message = 'error performing reload';
        messageBus.addEvent(BusEvent('reload.end', data: message));
        status.setText(message);
      } finally {
        reloadAction.disabled = false;
        status.timeout();
      }
    });

    addGlobalAction(reloadAction);
  }

  void _buildRestartButton() async {
    final HtmlActionButton restartAction = HtmlActionButton(
      _restartActionId,
      FlutterIcons.hotRestartWhite,
      'Hot Restart',
    );
    restartAction.click(() async {
      // Hide any previous status related to reload / restart.
      reloadStatus?.dispose();

      final HtmlStatus status = HtmlStatus(auxiliaryStatus, 'restarting...');
      reloadStatus = status;

      final Stopwatch timer = Stopwatch()..start();

      try {
        restartAction.disabled = true;
        messageBus.addEvent(BusEvent('restart.start'));
        await serviceManager.performHotRestart();
        timer.stop();
        // 'restarted in 1.6s'
        final String message = 'restarted in ${_renderDuration(timer.elapsed)}';
        messageBus.addEvent(BusEvent('restart.end', data: message));
        status.setText(message);
        ga.select(ga.devToolsMain, ga.hotRestart, timer.elapsed.inMilliseconds);
      } catch (_) {
        const String message = 'error performing restart';
        messageBus.addEvent(BusEvent('restart.end', data: message));
        status.setText(message);
      } finally {
        restartAction.disabled = false;
        status.timeout();
      }
    });

    addGlobalAction(restartAction);
  }

  void _rebuildConnectionStatus() {
    if (serviceManager.hasConnection) {
      if (connectionStatus != null) {
        auxiliaryStatus.remove(connectionStatus);
        connectionStatus = null;
      }
    } else {
      if (connectionStatus == null) {
        connectionStatus = HtmlStatusItem();
        auxiliaryStatus.add(connectionStatus);
      }
      connectionStatus.element.text = 'no device connected';
    }
  }
}

class HtmlNotFoundScreen extends HtmlScreen {
  HtmlNotFoundScreen() : super(name: 'Not Found', id: 'notfound');

  @override
  CoreElement createContent(HtmlFramework framework) {
    return p(text: 'Page not found: ${html.window.location.pathname}');
  }
}

class HtmlStatus {
  HtmlStatus(this.statusLine, String initialMessage) {
    item = HtmlStatusItem();
    item.element.text = initialMessage;

    statusLine.add(item);
  }

  final HtmlStatusLine statusLine;
  HtmlStatusItem item;

  void setText(String newText) {
    item.element.text = newText;
  }

  void timeout() {
    Timer(const Duration(seconds: 3), dispose);
  }

  void dispose() {
    statusLine.remove(item);
  }
}

String _renderDuration(Duration duration) {
  if (duration.inMilliseconds < 1000) {
    return '${nf.format(duration.inMilliseconds)}ms';
  } else {
    return '${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
  }
}
