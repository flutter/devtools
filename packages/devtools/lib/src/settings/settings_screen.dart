// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../service_registrations.dart' as registrations;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../version.dart';
import 'settings_controller.dart';

class FlagDetailsUI extends CoreElement {
  FlagDetailsUI(Flag flag) : super('div', classes: 'flag-details-container') {
    final flagDescription = div(c: 'flag-details-descriptions-container')
      ..add(<CoreElement>[
        h5(text: flag.name),
        span(c: 'flag-description', text: flag.comment),
      ]);

    final flagValues = div(c: 'flag-details-values-container')
      ..layoutVertical()
      ..add(<CoreElement>[
        span(c: 'flag-value', text: flag.valueAsString),
        span(c: 'flag-modified', text: flag.modified ? 'modified' : 'default')
      ]);

    add(<CoreElement>[
      flagDescription,
      flagValues,
    ]);
  }
}

class SettingsScreen extends Screen {
  SettingsScreen()
      : super(
          name: '',
          id: 'settings',
          iconClass: 'octicon-gear masthead-item action-button active',
          showTab: false,
        ) {
    _controller = SettingsController(
      onFlagListChange: (FlagList flagList) {
        _flagList.add(flagList.flags.map((flag) => FlagDetailsUI(flag)));
      },
      onSdkVersionChange: (String sdkVersion) {
        _sdkVersion.text = sdkVersion;
      },
    );
  }

  CoreElement _flagList;

  CoreElement _sdkVersionContainer;

  CoreElement _sdkVersion;

  CoreElement _flutterVersionContainer;

  CoreElement _versionContainer;

  Spinner _loadingVersionSpinner;

  SettingsController _controller;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();
    this.framework = framework;

    _initContent();
    _checkForFlutterVersionService();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    screenDiv
      ..add([
        div(c: 'section')
          ..add([
            h2(text: 'Version Information'),
            _versionContainer,
          ]),
        div(c: 'section')
          ..flex()
          ..add([
            h2(text: 'Dart VM Flag List'),
            div(c: 'flag-list-container')
              ..flex()
              ..add(_flagList),
          ])
      ]);

    _controller.entering();
    return screenDiv;
  }

  void _initContent() {
    _flagList = div(c: 'flag-list')..layoutVertical();

    _versionContainer = div(c: 'version-container')
      ..layoutVertical()
      ..flex()
      ..add([
        _loadingVersionSpinner = Spinner.centered(),
        _sdkVersionContainer = div()
          ..layoutHorizontal()
          ..add([
            h5(text: 'Dart SDK:'),
            _sdkVersion = h5(c: 'version-value'),
          ])
          ..hidden(true),
        _flutterVersionContainer = div()
          ..layoutVertical()
          ..hidden(true)
      ]);
  }

  void _checkForFlutterVersionService() async {
    // Wait for a small delay to give DevTools a chance to pick up the
    // registered service. This prevents the version UI from flickering.
    await Future.delayed(const Duration(seconds: 1));

    if (await serviceManager.connectedApp.isAnyFlutterApp) {
      serviceManager.hasRegisteredService(
        registrations.flutterVersion.service,
        (bool serviceAvailable) async {
          if (serviceAvailable) {
            final FlutterVersion version =
                await _controller.getFlutterVersion();
            _updateVersionUI(useFlutterVersionData: true, version: version);
          } else {
            _updateVersionUI(useFlutterVersionData: false);
          }
        },
      );
    } else {
      _updateVersionUI(useFlutterVersionData: false);
    }
    _loadingVersionSpinner.remove();
  }

  void _updateVersionUI({
    @required bool useFlutterVersionData,
    FlutterVersion version,
  }) {
    if (useFlutterVersionData && version != null) {
      _flutterVersionContainer
        ..clear()
        ..add([
          div()
            ..layoutHorizontal()
            ..add([
              h5(text: 'Flutter:'),
              h5(c: 'version-value', text: version.flutterDisplay),
            ]),
          div()
            ..layoutHorizontal()
            ..add([
              h5(text: 'Framework:'),
              h5(c: 'version-value', text: version.frameworkDisplay),
            ]),
          div()
            ..layoutHorizontal()
            ..add([
              h5(text: 'Engine:'),
              h5(c: 'version-value', text: version.engineDisplay),
            ]),
          div()
            ..layoutHorizontal()
            ..add([
              h5(text: 'Dart SDK:'),
              h5(c: 'version-value', text: version.dartSdkVersion),
            ]),
        ]);
    }
    _sdkVersionContainer.hidden(useFlutterVersionData);
    _flutterVersionContainer.hidden(!useFlutterVersionData);
  }
}
