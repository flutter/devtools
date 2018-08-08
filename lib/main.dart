// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide Screen;

import 'package:vm_service_lib/vm_service_lib.dart';

import 'device/device.dart';
import 'framework/framework.dart';
import 'globals.dart';
import 'logging/logging.dart';
import 'memory/memory.dart';
import 'performance/performance.dart';
import 'service.dart';
import 'timeline/timeline.dart';
import 'ui/elements.dart';
import 'ui/primer.dart';
import 'utils.dart';

// TODO: notification when the debug process goes away

// TODO: make the screens more robust through restarts

// TODO: make the screens gather info when not the active screen, and refresh
//       the UI on re-activate

class PerfToolFramework extends Framework {
  StatusItem isolateSelectStatus;
  PSelect isolateSelect;

  PerfToolFramework() {
    setGlobal(ServiceConnectionManager, new ServiceConnectionManager());

    addScreen(new MemoryScreen());
    addScreen(new TimelineScreen());
    addScreen(new PerformanceScreen());
    addScreen(new DeviceScreen());
    addScreen(new LoggingScreen());

    initGlobalUI();
  }

  void initGlobalUI() {
    CoreElement mainNav = new CoreElement.from(querySelector('#main-nav'));
    mainNav.clear();

    for (Screen screen in screens) {
      CoreElement link = new CoreElement('a')
        ..attributes['href'] = screen.ref
        ..onClick.listen((MouseEvent e) {
          e.preventDefault();
          navigateTo(screen.id);
        })
        ..add([
          span(c: 'octicon ${screen.iconClass}'),
          span(text: ' ${screen.name}')
        ]);
      mainNav.add(link);
      if (!screen.visible) {
        link.disabled = true;
      }
      screen.onVisibleChange.listen((_) {
        link.disabled = !screen.visible;
      });
    }

    // TODO: isolate selector should use the rich pulldown UI
    isolateSelectStatus = new StatusItem();
    globalStatus.add(isolateSelectStatus);
    isolateSelect = select()
      ..small()
      ..change(_handleIsolateSelect);
    isolateSelectStatus.element.add(isolateSelect);
    _rebuildIsolateSelect();
    serviceInfo.isolateManager.onIsolateCreated.listen(_rebuildIsolateSelect);
    serviceInfo.isolateManager.onIsolateExited.listen(_rebuildIsolateSelect);
    serviceInfo.isolateManager.onSelectedIsolateChanged
        .listen(_rebuildIsolateSelect);
  }

  IsolateRef get currentIsolate => serviceInfo.isolateManager.selectedIsolate;

  void _handleIsolateSelect() {
    serviceInfo.isolateManager.selectIsolate(isolateSelect.value);
  }

  void _rebuildIsolateSelect([_]) {
    isolateSelect.clear();
    for (IsolateRef ref in serviceInfo.isolateManager.isolates) {
      isolateSelect.option(isolateName(ref), value: ref.id);
    }
    isolateSelect.disabled = serviceInfo.isolateManager.isolates.isEmpty;
    if (serviceInfo.isolateManager.selectedIsolate != null) {
      isolateSelect.selectedIndex = serviceInfo.isolateManager.isolates
          .indexOf(serviceInfo.isolateManager.selectedIsolate);
    }
  }
}

class NotFoundScreen extends Screen {
  NotFoundScreen() : super('Not Found', 'notfound');

  void createContent(Framework framework, CoreElement mainDiv) {
    mainDiv.add(p(text: 'Page not found: ${window.location.pathname}'));
  }
}
