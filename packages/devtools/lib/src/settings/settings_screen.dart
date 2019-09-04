// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools show version;
import '../framework/framework.dart';
import '../globals.dart';
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/elements.dart';
import '../version.dart';
import 'settings_controller.dart';

class FlagDetailsUI extends CoreElement {
  FlagDetailsUI(Flag flag) : super('div', classes: 'flag-details-container') {
    final flagDescription = div(c: 'flag-details-descriptions-container')
      ..add(<CoreElement>[
        div(c: 'setting-title', text: flag.name),
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
      onFlagListChanged: (FlagList flagList) {
        _flagList
          ..clear()
          ..add(flagList.flags.map((flag) => FlagDetailsUI(flag)));
      },
      onFlutterVersionChanged: (FlutterVersion version) {
        _updateFlutterVersionUI(version);
      },
    );
  }

  CoreElement _flagList;

  CoreElement _flutterVersionContainer;

  CoreElement _versionContainer;

  SettingsController _controller;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();
    this.framework = framework;
    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    _versionContainer = div(c: 'version-container')
      ..layoutVertical()
      ..flex()
      ..add([
        _flutterVersionContainer = div()
          ..layoutVertical()
          ..hidden(true),
        _versionDisplay(
          title: 'Dart SDK:',
          value: serviceManager.sdkVersion,
        ),
        _versionDisplay(
          title: 'DevTools:',
          value: devtools.version,
          includeMargin: false,
        ),
      ]);

    _flagList = div(c: 'flag-list')..layoutVertical();

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

  void _updateFlutterVersionUI(FlutterVersion version) {
    if (version != null) {
      _flutterVersionContainer
        ..clear()
        ..add([
          _versionDisplay(
            title: 'Flutter:',
            value: version.flutterVersionSummary,
          ),
          _versionDisplay(
            title: 'Framework:',
            value: version.frameworkVersionSummary,
          ),
          _versionDisplay(
            title: 'Engine:',
            value: version.engineVersionSummary,
          ),
        ]);
    }
    _flutterVersionContainer.hidden(version == null);
  }

  CoreElement _versionDisplay({
    @required String title,
    @required String value,
    bool includeMargin = true,
  }) {
    final versionDisplay = div()
      ..layoutHorizontal()
      ..add([
        div(c: 'setting-title', text: title),
        div(c: 'version-value', text: value),
      ]);
    if (includeMargin) versionDisplay.clazz('version-margin');
    return versionDisplay;
  }
}
