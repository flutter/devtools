// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import 'package:vm_service_lib/vm_service_lib.dart';

import 'core/message_bus.dart';
import 'debugger/debugger.dart';
import 'eval_on_dart_library.dart';
import 'framework/framework.dart';
import 'globals.dart';
import 'inspector/inspector.dart';
import 'logging/logging.dart';
import 'memory/memory.dart';
import 'model/model.dart';
import 'performance/performance.dart';
import 'service_registrations.dart' as registrations;
import 'timeline/timeline.dart';
import 'ui/custom.dart';
import 'ui/elements.dart';
import 'ui/icons.dart';
import 'ui/primer.dart';
import 'ui/ui_utils.dart';
import 'utils.dart';

// TODO(devoncarew): make the screens more robust through restarts

const bool showMemoryPage = false;
const bool showPerformancePage = false;

const flutterLibraryUri = 'package:flutter/src/widgets/binding.dart';
const flutterWebLibraryUri = 'package:flutter_web/src/widgets/binding.dart';

class PerfToolFramework extends Framework {
  PerfToolFramework() {
    initGlobalUI();
    initTestingModel();
  }

  StatusItem isolateSelectStatus;
  PSelect isolateSelect;

  StatusItem connectionStatus;
  Status reloadStatus;

  static const _reloadTooltip = 'Hot Reload';
  static const _restartTooltip = 'Hot Restart';

  void initGlobalUI() async {
    await serviceManager.serviceAvailable.future;
    await addScreens();
    sortScreens();
    screensReady.complete();

    final CoreElement mainNav = CoreElement.from(queryId('main-nav'));
    mainNav.clear();

    for (Screen screen in screens) {
      final CoreElement link = CoreElement('a')
        ..add(<CoreElement>[
          span(c: 'octicon ${screen.iconClass}'),
          span(text: ' ${screen.name}')
        ]);
      if (screen.disabled) {
        link
          ..onClick.listen((MouseEvent e) {
            e.preventDefault();
            toast(link.tooltip);
          })
          ..toggleClass('disabled', true)
          ..tooltip = screen.disabledTooltip;
      } else {
        link
          ..attributes['href'] = screen.ref
          ..onClick.listen((MouseEvent e) {
            e.preventDefault();
            navigateTo(screen.id);
          });
      }
      mainNav.add(link);
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

    // Listen for clicks on the 'send feedback' button.
    queryId('send-feedback-button').onClick.listen((_) {
      // TODO(devoncarew): Fill in useful product info here, like the Flutter
      // SDK version and the version of DevTools in use.
      window.open('https://github.com/flutter/devtools/issues', '_feedback');
    });
  }

  void initTestingModel() {
    App.register(this);
  }

  void disableAppWithError(String title, [dynamic error]) {
    document
        .getElementById('header')
        .children
        .removeWhere((e) => e.id != 'title');
    document.getElementById('content').children.clear();
    showError(title, error);
  }

  Future<bool> isFlutterApp() async {
    final EvalOnDartLibrary flutterLibrary = EvalOnDartLibrary(
      [flutterLibraryUri, flutterWebLibraryUri],
      serviceManager.service,
    );

    try {
      await flutterLibrary.libraryRef;
    } on LibraryNotFound catch (_) {
      return false;
    }
    return true;
  }

  Future<bool> isFlutterWebApp() async {
    // TODO(kenzie): fix this if screens should still be disabled when flutter
    // merges with flutter_web.
    final EvalOnDartLibrary flutterWebLibrary = EvalOnDartLibrary(
      [flutterWebLibraryUri],
      serviceManager.service,
    );

    try {
      await flutterWebLibrary.libraryRef;
    } on LibraryNotFound catch (_) {
      return false;
    }
    return true;
  }

  Future<bool> isProfileBuild() async {
    try {
      final Isolate isolate = await serviceManager.service
          .getIsolate(serviceManager.isolateManager.isolates.first.id);
      // This evaluate statement will throw an error in a profile build.
      await serviceManager.service.evaluate(
        serviceManager.isolateManager.isolates.first.id,
        isolate.rootLib.id,
        '1+1',
      );
      // If we reach this return statement, no error was thrown and this is not
      // a profile build.
      return false;
    } on RPCError catch (_) {
      return true;
    }
  }

  Future<void> addScreens() async {
    final _isFlutterApp = await isFlutterApp();
    final _isFlutterWebApp = await isFlutterWebApp();
    final _isProfileBuild = await isProfileBuild();

    addScreen(InspectorScreen(
      disabled: !_isFlutterApp || !_isFlutterWebApp || _isProfileBuild,
      disabledTooltip: (!_isFlutterApp || !_isFlutterWebApp)
          ? 'This screen is disabled because you are not running a Flutter '
              'application'
          : 'This screen is disabled because you are running a profile build '
          'of your application',
    ));
    addScreen(TimelineScreen(
      disabled: !_isFlutterApp || _isFlutterWebApp,
      disabledTooltip: _isFlutterWebApp
          ? 'This screen is disabled because it is not yet ready for Flutter'
              ' Web'
          : 'This screen is disabled because you are not running a '
          'Flutter application',
    ));
    addScreen(MemoryScreen(
      disabled: _isFlutterWebApp,
      disabledTooltip:
          'This screen is disabled because it is not yet ready for Flutter'
          ' Web',
    ));
    if (showPerformancePage) {
      addScreen(PerformanceScreen());
    }

    addScreen(DebuggerScreen(
      disabled:
          _isFlutterWebApp || _isProfileBuild || tabDisabledByQuery('debugger'),
      disabledTooltip: _isFlutterWebApp
          ? 'This screen is disabled because it is not yet ready for Flutter'
              ' Web'
          : (_isProfileBuild
              ? 'This screen is disabled because you are running a profile '
                  'build of your application'
              : 'This screen is disabled because it provides functionality '
              'already available in your code editor'),
    ));
    addScreen(LoggingScreen());
  }

  void sortScreens() {
    // Move disabled screens to the end, but otherwise preserve order.
    final sortedScreens = screens
        .where((screen) => !screen.disabled)
        .followedBy(screens.where((screen) => screen.disabled))
        .toList();
    screens.clear();
    screens.addAll(sortedScreens);
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
          removeGlobalAction(_reloadTooltip);
        }
      },
    );

    serviceManager.hasRegisteredService(
      registrations.hotRestart.service,
      (bool reloadServiceAvailable) {
        if (reloadServiceAvailable) {
          _buildRestartButton();
        } else {
          removeGlobalAction(_restartTooltip);
        }
      },
    );
  }

  void _buildReloadButton() async {
    // TODO(devoncarew): We currently create hot reload events when hot reload
    // is initialed, and react to those events in the UI. Going forward, we'll
    // want to instead have flutter_tools fire hot reload events, and react to
    // them in the UI. That will mean that our UI will update appropriately
    // even when other clients (the CLI, and IDE) initial the hot reload.

    final ActionButton reloadAction =
        ActionButton(FlutterIcons.hotReloadWhite, _reloadTooltip);
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
    final ActionButton restartAction =
        ActionButton(FlutterIcons.hotRestartWhite, _restartTooltip);
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
        connectionStatus = new StatusItem();
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
    return p(text: 'Page not found: ${window.location.pathname}');
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
