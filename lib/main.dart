// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide Screen;

import 'package:vm_service_lib/vm_service_lib.dart';

import 'debugger/debugger.dart';
import 'device/device.dart';
import 'framework/framework.dart';
import 'globals.dart';
import 'logging/logging.dart';
import 'memory/memory.dart';
import 'model/model.dart';
import 'performance/performance.dart';
import 'timeline/timeline.dart';
import 'ui/elements.dart';
import 'ui/primer.dart';
import 'utils.dart';

// TODO(devoncarew): notification when the debug process goes away

// TODO(devoncarew): make the screens more robust through restarts

// TODO(devoncarew): make the screens gather info when not the active screen,
// and refresh the UI on re-activate

class PerfToolFramework extends Framework {
  PerfToolFramework() {
    addScreen(DebuggerScreen());
    addScreen(MemoryScreen());
    addScreen(TimelineScreen());
    addScreen(PerformanceScreen());
    addScreen(DeviceScreen());
    addScreen(LoggingScreen());

    initGlobalUI();

    initTestingModel();
  }

  StatusItem isolateSelectStatus;
  PSelect isolateSelect;

  StatusItem connectionStatus;

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
    isolateSelect = select()
      ..small()
      ..change(_handleIsolateSelect);
    isolateSelectStatus.element.add(isolateSelect);
    _rebuildIsolateSelect();

    serviceManager.isolateManager.onIsolateCreated
        .listen(_rebuildIsolateSelect);
    serviceManager.isolateManager.onIsolateExited.listen(_rebuildIsolateSelect);
    serviceManager.isolateManager.onSelectedIsolateChanged
        .listen(_rebuildIsolateSelect);

    connectionStatus = StatusItem();
    auxiliaryStatus.add(connectionStatus);

    serviceManager.onStateChange.listen((_) {
      _rebuildConnectionStatus();
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

  void _rebuildConnectionStatus() {
    if (serviceManager.hasConnection) {
      final String description = '${serviceManager.vm.targetCPU}, '
          '${serviceManager.vm.architectureBits}-bit';
      connectionStatus.element.text = 'connected to device ($description)';
    } else {
      connectionStatus.element.text = 'no device connected';
    }
  }
}

class NotFoundScreen extends Screen {
  NotFoundScreen() : super(name: 'Not Found', id: 'notfound');

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    mainDiv.add(p(text: 'Page not found: ${window.location.pathname}'));
  }
}
