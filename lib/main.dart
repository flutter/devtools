// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' hide Screen;

import 'package:vm_service_lib/vm_service_lib.dart';

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
import 'utils.dart';

// TODO(devoncarew): make the screens more robust through restarts

const bool showMemoryPage = false;
const bool showPerformancePage = false;

class PerfToolFramework extends Framework {
  PerfToolFramework() {
    addScreen(InspectorScreen());
    addScreen(TimelineScreen());
    addScreen(DebuggerScreen());
    if (showMemoryPage) {
      addScreen(MemoryScreen());
    }
    if (showPerformancePage) {
      addScreen(PerformanceScreen());
    }
    addScreen(LoggingScreen());

    initGlobalUI();

    initTestingModel();
  }

  StatusItem isolateSelectStatus;
  PSelect isolateSelect;

  StatusItem connectionStatus;
  Status reloadStatus;

  void initGlobalUI() {
    final CoreElement mainNav = CoreElement.from(querySelector('#main-nav'));
    mainNav.clear();

    for (Screen screen in screens) {
      final CoreElement link = CoreElement('a')
        ..attributes['href'] = screen.ref
        ..onClick.listen((MouseEvent e) {
          e.preventDefault();
          navigateTo(screen.id);
        })
        ..add(<CoreElement>[
          span(c: 'octicon ${screen.iconClass}'),
          span(text: ' ${screen.name}')
        ]);
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

    _initHotReloadServiceListener();

    serviceManager.onStateChange.listen((_) {
      _rebuildConnectionStatus();

      if (!serviceManager.hasConnection) {
        toast('Device connection lost.');
      }
    });
  }

  void initTestingModel() {
    App.register(this);
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

  void _initHotReloadServiceListener() {
    final hotReloadServiceName = registrations.hotReload.service;
    serviceManager.hasRegisteredService(hotReloadServiceName,
        (bool reloadServiceAvailable) {
      if (reloadServiceAvailable) {
        _buildReloadRestartButtons();
      } else {
        clearGlobalActions();
      }
    });
  }

  void _buildReloadRestartButtons() async {
    final ActionButton reloadAction =
        ActionButton('icons/hot-reload-white@2x.png', 'Hot Reload');
    reloadAction.click(() async {
      // Hide any previous status related to reload.
      reloadStatus?.dispose();

      final Status status = Status(auxiliaryStatus, 'reloading...');
      reloadStatus = status;

      final Stopwatch timer = Stopwatch()..start();

      try {
        reloadAction.disabled = true;
        await serviceManager.performHotReload();
        timer.stop();
        // 'reloaded in 600ms'
        status.setText('reloaded in ${nf.format(timer.elapsedMilliseconds)}ms');
      } catch (_) {
        status.setText('error performing reload');
      } finally {
        reloadAction.disabled = false;
        status.timeout();
      }
    });

    final ActionButton restartAction =
        ActionButton('icons/hot-restart-white@2x.png', 'Hot Restart');
    restartAction.click(() async {
      // Hide any previous status related to reload.
      reloadStatus?.dispose();

      final Status status = Status(auxiliaryStatus, 'restarting...');
      reloadStatus = status;

      final Stopwatch timer = Stopwatch()..start();

      try {
        restartAction.disabled = true;
        await serviceManager.performHotRestart();
        timer.stop();
        // 'restarted in 1.6s'
        status.setText(
            'restarted in ${(timer.elapsedMilliseconds / 1000).toStringAsFixed(1)}s');
      } catch (_) {
        status.setText('error performing reload');
      } finally {
        restartAction.disabled = false;
        status.timeout();
      }
    });

    addGlobalAction(reloadAction);
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
