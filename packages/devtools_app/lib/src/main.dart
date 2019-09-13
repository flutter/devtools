// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'package:html_shim/html.dart' as html;

import 'package:vm_service/vm_service.dart';

import 'config_specific/logger.dart';
import 'core/message_bus.dart';
import 'debugger/debugger.dart';
import 'framework/framework.dart';
import 'globals.dart';
import 'info/info_screen.dart';
import 'inspector/inspector.dart';
import 'logging/logging.dart';
import 'memory/memory.dart';
import 'model/model.dart';
import 'performance/performance_screen.dart';
import 'service_registrations.dart' as registrations;
import 'timeline/timeline_screen.dart';
import 'ui/analytics.dart' as ga;
import 'ui/analytics_platform.dart' as ga_platform;
import 'ui/custom.dart';
import 'ui/elements.dart';
import 'ui/icons.dart';
import 'ui/primer.dart';
import 'ui/ui_utils.dart';
import 'utils.dart';

// TODO(devoncarew): make the screens more robust through restarts

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const flutterWebLibraryUri = 'package:flutter_web/src/widgets/binding.dart';

class PerfToolFramework extends Framework {
  PerfToolFramework() {
    html.window.onError.listen(_gAReportExceptions);

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

  StatusItem isolateSelectStatus;
  PSelect isolateSelect;

  StatusItem connectionStatus;
  Status reloadStatus;

  static const _reloadActionId = 'reload-action';
  static const _restartActionId = 'restart-action';

  void initGlobalUI() async {
    // Listen for clicks on the 'send feedback' button.
    queryId('send-feedback-button').onClick.listen((_) {
      ga.select(ga.devToolsMain, ga.feedback);
      // TODO(devoncarew): Fill in useful product info here, like the Flutter
      // SDK version and the version of DevTools in use.
      html.window
          .open('https://github.com/flutter/devtools/issues', '_feedback');
    });

    await serviceManager.serviceAvailable.future;
    await addScreens();
    screensReady.complete();

    final mainNav = CoreElement.from(queryId('main-nav'))..clear();
    final iconNav = CoreElement.from(queryId('icon-nav'))..clear();

    for (Screen screen in screens) {
      final link = CoreElement('a')
        ..add(<CoreElement>[
          span(c: 'octicon ${screen.iconClass}'),
          span(text: ' ${screen.name}', c: 'optional-1060')
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

    isolateSelectStatus = StatusItem();
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
    final app = App.register(this);
    screensReady.future.then(app.devToolsReady);
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
    final isDartCliApp = app.isRunningOnDartVM && !isFlutterApp;
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

    addScreen(InspectorScreen(
      enabled: isFlutterApp && !isFlutterVmProfileBuild,
      disabledTooltip: isFlutterVmProfileBuild
          ? runningProfileBuildMsg
          : notRunningFlutterMsg,
    ));
    addScreen(TimelineScreen(
      enabled: isFlutterApp && !isFlutterWebApp,
      disabledTooltip:
          isFlutterWebApp ? notFlutterWebMsg : notRunningFlutterMsg,
    ));
    addScreen(MemoryScreen(
      enabled: isFlutterVmApp || isDartCliApp,
      disabledTooltip: isFlutterWebApp ? notFlutterWebMsg : notDartWebMsg,
      isProfileBuild: isFlutterVmProfileBuild,
    ));
    addScreen(PerformanceScreen(
      enabled: isFlutterVmApp || isDartCliApp,
      disabledTooltip: isFlutterWebApp ? notFlutterWebMsg : notDartWebMsg,
    ));
    addScreen(DebuggerScreen(
        enabled: !isFlutterVmProfileBuild && !isTabDisabledByQuery('debugger'),
        disabledTooltip: isFlutterVmProfileBuild
            ? runningProfileBuildMsg
            : duplicateDebuggerFunctionalityMsg));
    addScreen(LoggingScreen());
    addScreen(InfoScreen());
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
    serviceManager.hasRegisteredService(
      registrations.hotReload.service,
      (bool reloadServiceAvailable) {
        if (reloadServiceAvailable) {
          _buildReloadButton();
        } else {
          removeGlobalAction(_reloadActionId);
        }
      },
    );

    serviceManager.hasRegisteredService(
      registrations.hotRestart.service,
      (bool reloadServiceAvailable) {
        if (reloadServiceAvailable) {
          _buildRestartButton();
        } else {
          removeGlobalAction(_restartActionId);
        }
      },
    );
  }

  void _buildReloadButton() async {
    // TODO(devoncarew): We currently create hot reload events when hot reload
    // is initialed, and react to those events in the UI. Going forward, we'll
    // want to instead have flutter_tools fire hot reload events, and react to
    // them in the UI. That will mean that our UI will update appropriately
    // even when other clients (the CLI, and IDE) initiate the hot reload.

    final ActionButton reloadAction = ActionButton(
      _reloadActionId,
      FlutterIcons.hotReloadWhite,
      'Hot Reload',
    );
    reloadAction.click(() async {
      // Hide any previous status related to / restart.
      reloadStatus?.dispose();

      final Status status = Status(auxiliaryStatus, 'reloading...');
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
    final ActionButton restartAction = ActionButton(
      _restartActionId,
      FlutterIcons.hotRestartWhite,
      'Hot Restart',
    );
    restartAction.click(() async {
      // Hide any previous status related to reload / restart.
      reloadStatus?.dispose();

      final Status status = Status(auxiliaryStatus, 'restarting...');
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
        connectionStatus = StatusItem();
        auxiliaryStatus.add(connectionStatus);
      }
      connectionStatus.element.text = 'no device connected';
    }
  }
}

class NotFoundScreen extends Screen {
  NotFoundScreen() : super(name: 'Not Found', id: 'notfound');

  @override
  CoreElement createContent(Framework framework) {
    return p(text: 'Page not found: ${html.window.location.pathname}');
  }
}

class Status {
  Status(this.statusLine, String initialMessage) {
    item = StatusItem();
    item.element.text = initialMessage;

    statusLine.add(item);
  }

  final StatusLine statusLine;
  StatusItem item;

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
