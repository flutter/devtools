// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/elements.dart';

// TODO(devoncarew): set toggle values on a full restart (when we see a new isolate)

class DeviceScreen extends Screen {
  StatusItem deviceStatus;

  SetStateMixin framesChartStateMixin = new SetStateMixin();
  ExtensionTracker extensionTracker;

  CoreElement togglesDiv;
  Map<String, bool> boolValues = {};

  DeviceScreen()
      : super(
            name: 'Device', id: 'device', iconClass: 'octicon-device-mobile') {
    visible = false;

    serviceInfo.onConnectionAvailable.listen(_handleConnectionStart);
    serviceInfo.onConnectionClosed.listen(_handleConnectionStop);

    deviceStatus = new StatusItem();
    addStatusItem(deviceStatus);
  }

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    mainDiv.add([
      div(c: 'section')
        ..add([
          form()
            ..layoutHorizontal()
            ..add([
              div()..flex(),
            ])
        ]),
      div(c: 'section')
        ..add([
          div(text: 'Framework toggles', c: 'title'),
          togglesDiv = div(),
        ])
    ]);

    _rebuildTogglesDiv();
  }

  void _handleConnectionStart(VmService service) {
    extensionTracker = new ExtensionTracker(service);
    extensionTracker.start();

    extensionTracker.onChange.listen((_) {
      framesChartStateMixin.setState(() {
        if (extensionTracker.hasIsolateTargets && !visible) {
          visible = true;
        }

        _rebuildTogglesDiv();
      });
    });

    deviceStatus.element.text =
        '${serviceInfo.vm.targetCPU} ${serviceInfo.vm.architectureBits}-bit';
  }

  void _handleConnectionStop(dynamic event) {
    extensionTracker?.stop();

    deviceStatus.element.text = '';
  }

  HelpInfo get helpInfo => null;

  void _rebuildTogglesDiv() {
    if (togglesDiv == null || extensionTracker == null) return;

    togglesDiv.clear();

    _createBoolToggle('ext.flutter.debugPaint');
    _createBoolToggle('ext.flutter.debugPaintBaselinesEnabled');
    _createBoolToggle('ext.flutter.repaintRainbow');
    _createBoolToggle('ext.flutter.showPerformanceOverlay');
    _createBoolToggle('ext.flutter.debugAllowBanner');
  }

  void _createBoolToggle(String rpc) {
    if (!extensionTracker.extensionToIsolatesMap.containsKey(rpc)) {
      return;
    }

    CoreElement input;

    togglesDiv.add(div(c: 'form-checkbox')
      ..add(new CoreElement('label')
        ..add([
          input = new CoreElement('input')..setAttribute('type', 'checkbox'),
          span(text: rpc),
        ])));

    if (boolValues.containsKey(rpc)) {
      input.toggleAttribute('checked', boolValues[rpc]);
    } else {
      extensionTracker.callBoolExtensionMethod(rpc).then((bool value) {
        input.toggleAttribute('checked', value);
        boolValues[rpc] = value;
      });
    }

    input.element.onChange.listen((_) {
      html.InputElement e = input.element;
      boolValues[rpc] = e.checked;
      extensionTracker.setBoolExtensionMethod(rpc, e.checked);
    });
  }
}

class ExtensionTracker {
  final StreamController _changeController = new StreamController.broadcast();

  VmService service;

  Map<String, Set<IsolateRef>> extensionToIsolatesMap = {};

  ExtensionTracker(this.service) {
    service.onIsolateEvent.listen((Event e) {
      if (e.kind == 'ServiceExtensionAdded') {
        _registerRpcForIsolate(e.extensionRPC, e.isolate);
      }
    });

    serviceInfo.isolateManager.isolates.forEach(_register);
    serviceInfo.isolateManager.onIsolateCreated.listen(_register);
    serviceInfo.isolateManager.onIsolateExited.listen(_removeIsolate);
  }

  bool get hasConnection => service != null;

  Stream get onChange => _changeController.stream;

  bool get hasIsolateTargets {
    for (Set set in extensionToIsolatesMap.values) {
      if (set.isNotEmpty) {
        return true;
      }
    }

    return false;
  }

  void start() {}

  void stop() {}

  void _register(IsolateRef isolateRef) {
    service.getIsolate(isolateRef.id).then((result) {
      if (result is Isolate) {
        Isolate isolate = result;

        for (String rpc in isolate.extensionRPCs) {
          if (!extensionToIsolatesMap.containsKey(rpc)) {
            extensionToIsolatesMap[rpc] = new Set();
          }
          extensionToIsolatesMap[rpc].add(isolateRef);
        }
      }

      _changeController.add(null);
    });
  }

  void _registerRpcForIsolate(String rpc, IsolateRef isolateRef) {
    if (!extensionToIsolatesMap.containsKey(rpc)) {
      extensionToIsolatesMap[rpc] = new Set();
    }
    extensionToIsolatesMap[rpc].add(isolateRef);
  }

  void _removeIsolate(IsolateRef isolateRef) {
    for (Set set in extensionToIsolatesMap.values) {
      set.remove(isolateRef);
    }
  }

  Future<bool> callBoolExtensionMethod(String rpc) {
    IsolateRef isolateRef = extensionToIsolatesMap[rpc].first;
    return service
        .callServiceExtension(rpc, isolateId: isolateRef.id)
        .then((Response response) {
      return _convertToBool(response.json['enabled']);
    });
  }

  Future setBoolExtensionMethod(String rpc, bool checked) {
    IsolateRef isolateRef = extensionToIsolatesMap[rpc].first;
    return service.callServiceExtension(rpc,
        isolateId: isolateRef.id, args: {'enabled': checked});
  }

  static bool _convertToBool(val) {
    if (val is bool) return val;
    return val.toString() == 'true';
  }
}
