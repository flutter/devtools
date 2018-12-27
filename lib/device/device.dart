// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:html' as html;

import 'package:devtools/service_extensions.dart' as extensions;

import '../framework/framework.dart';
import '../globals.dart';
import '../service_manager.dart' show ServiceExtensionState;
import '../ui/elements.dart';

class DeviceScreen extends Screen {
  DeviceScreen()
      : super(
            name: 'Device', id: 'device', iconClass: 'octicon-device-mobile') {
    deviceStatus = new StatusItem();
    addStatusItem(deviceStatus);
  }

  StatusItem deviceStatus;
  CoreElement togglesDiv;

  // All the service extensions for which we are showing checkboxes.
  Map<String, CoreElement> serviceExtensionCheckboxes = {};

  @override
  void createContent(Framework framework, CoreElement mainDiv) {
    mainDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..layoutHorizontal()
            ..add(<CoreElement>[
              div()..flex(),
            ])
        ]),
      div(c: 'section')
        ..add(<CoreElement>[
          div(text: 'Framework toggles', c: 'title'),
          togglesDiv = div(),
        ])
    ]);

    _buildTogglesDiv();
  }

  @override
  HelpInfo get helpInfo => null;

  void _buildTogglesDiv() {
    if (togglesDiv == null) {
      return;
    }

    _createBoolToggle(extensions.debugPaint);
    _createBoolToggle(extensions.debugPaintBaselines);
    _createBoolToggle(extensions.repaintRainbow);
    _createBoolToggle(extensions.performanceOverlay);
    _createBoolToggle(extensions.debugAllowBanner);
    _createBoolToggle(extensions.profileWidgetBuilds);
  }

  void _createBoolToggle(String rpc) {
    serviceManager.serviceExtensionManager.hasServiceExtension(rpc,
        (bool available) {
      if (!available || serviceExtensionCheckboxes.containsKey(rpc)) {
        return;
      }

      CoreElement input;

      togglesDiv.add(div(c: 'form-checkbox')
        ..add(new CoreElement('label')
          ..add(<CoreElement>[
            input = new CoreElement('input')..setAttribute('type', 'checkbox'),
            span(text: rpc),
          ])));
      serviceExtensionCheckboxes[rpc] = input;

      serviceManager.serviceExtensionManager.getServiceExtensionState(rpc,
          (ServiceExtensionState state) {
        final bool value = state.value ?? false;
        input.toggleAttribute('checked', value);
      });

      input.element.onChange.listen((_) {
        final html.InputElement e = input.element;
        serviceManager.serviceExtensionManager
            .setServiceExtensionState(rpc, e.checked, e.checked);
      });
    });
  }
}
