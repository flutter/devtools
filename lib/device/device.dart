// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../framework/framework.dart';
import '../globals.dart';
import '../service_extensions.dart' as extensions;
import '../ui/elements.dart';
import '../ui/ui_utils.dart';

class DeviceScreen extends Screen {
  DeviceScreen()
      : super(
            name: 'Device', id: 'device', iconClass: 'octicon-device-mobile') {
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

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

  void _handleConnectionStop(dynamic event) {
    deviceStatus.element.text = '';
  }

  @override
  HelpInfo get helpInfo => null;

  void _buildTogglesDiv() {
    if (togglesDiv == null) {
      return;
    }

    togglesDiv.add(createExtensionCheckBox(extensions.debugPaint));
    togglesDiv.add(createExtensionCheckBox(extensions.debugPaintBaselines));
    togglesDiv.add(createExtensionCheckBox(extensions.repaintRainbow));
    togglesDiv.add(createExtensionCheckBox(extensions.performanceOverlay));
    togglesDiv.add(createExtensionCheckBox(extensions.debugAllowBanner));
    togglesDiv.add(createExtensionCheckBox(extensions.profileWidgetBuilds));
  }
}
