// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import 'package:vm_service_lib/vm_service_lib.dart';

import 'core/message_bus.dart';
import 'debugger/debugger.dart';
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
import 'ui/primer.dart';
import 'ui/ui_utils.dart';
import 'utils.dart';

// TODO(devoncarew): make the screens more robust through restarts

const bool showMemoryPage = false;
const bool showPerformancePage = false;

class PerfToolFramework extends Framework {
  PerfToolFramework() {
    addScreen(InspectorScreen());
    addScreen(TimelineScreen());
    addScreen(MemoryScreen());
    if (showPerformancePage) {
      addScreen(PerformanceScreen());
    }
    addScreen(DebuggerScreen(disabled: shouldDisableTab('debugger')));
    addScreen(LoggingScreen());

    sortScreens();

    initGlobalUI();

    initTestingModel();
  }

  StatusItem isolateSelectStatus;
  PSelect isolateSelect;

  StatusItem connectionStatus;
  Status reloadStatus;

  static const _reloadTooltip = 'Hot Reload';
  static const _restartTooltip = 'Hot Restart';

  void initGlobalUI() {
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
          ..tooltip =
              'This section is disabled because it provides functionality already available in your code editor';
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

    final ActionButton reloadAction = ActionButton(
      'icons/hot-reload-white@2x.png',
      _reloadTooltip,
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
      'icons/hot-restart-white@2x.png',
      _restartTooltip,
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
