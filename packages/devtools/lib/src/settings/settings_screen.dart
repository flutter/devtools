// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools/src/settings/settings_controller.dart';
import 'package:vm_service/vm_service.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/elements.dart';

class FlagDetailsUI extends CoreElement {
  FlagDetailsUI(Flag flag) : super('div', classes: 'flag-details-container') {
    final flagDescription = div(c: 'flag-details-descriptions-container')
      ..add(<CoreElement>[
        CoreElement('h3', classes: 'flag-name', text: flag.name),
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
    _flagList = div(c: 'flag-list-container')
      ..layoutVertical()
      ..add(
        CoreElement('h2', text: 'Dart VM Flag List'),
      );
    _sdkVersion = div(c: 'sdk-version-container')..flex(2);

    _controller = SettingsController(
      onFlagListReady: (FlagList flagList) {
        _flagList.add(flagList.flags.map((flag) => FlagDetailsUI(flag)));
      },
      onIsAnyFlutterAppReady: (bool isAnyFlutterApp) {
        _sdkVersion
          ..add(<CoreElement>[
            CoreElement('h2',
                text: '${isAnyFlutterApp ? 'Flutter' : 'Dart'} SDK Version: '),
            span(text: serviceManager.sdkVersion),
          ]);
      },
    );
  }

  CoreElement _container;
  CoreElement _flagList;
  CoreElement _screenDiv;
  CoreElement _sdkVersion;

  SettingsController _controller;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();
    this.framework = framework;
    _screenDiv = div(c: 'custom-scrollbar')..layoutVertical();
    _container = div(c: 'settings-container');
    _screenDiv
      ..clear()
      ..add(_container..clear());
    _container.add(_sdkVersion);
    _container.add(_flagList);

    _controller.entering();
    return _screenDiv;
  }
}
