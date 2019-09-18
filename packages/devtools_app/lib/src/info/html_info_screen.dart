// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

import '../../devtools.dart' as devtools show version;
import '../framework/html_framework.dart';
import '../globals.dart';
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/html_elements.dart';
import '../version.dart';
import 'info_controller.dart';

class HtmlFlagDetails extends CoreElement {
  HtmlFlagDetails(Flag flag) : super('div', classes: 'flag-details-container') {
    final flagDescription = div(c: 'flag-details-descriptions-container')
      ..add(<CoreElement>[
        div(c: 'info-title', text: flag.name),
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

class HtmlInfoScreen extends HtmlScreen {
  HtmlInfoScreen()
      : super(
          name: '',
          id: 'info',
          iconClass: 'octicon-info',
          showTab: false,
        ) {
    _controller = InfoController(
      onFlagListChanged: (FlagList flagList) {
        _flagList
          ..clear()
          ..add(flagList.flags.map((flag) => HtmlFlagDetails(flag)));
      },
      onFlutterVersionChanged: (FlutterVersion version) {
        _updateFlutterVersionUI(version);
      },
    );
  }

  CoreElement _flagList;

  CoreElement _flutterVersionContainer;

  CoreElement _versionContainer;

  InfoController _controller;

  @override
  CoreElement createContent(HtmlFramework framework) {
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

    screenDiv
      ..add([
        div(c: 'section')
          ..add([
            h2(text: 'Version Information'),
            _versionContainer,
          ]),
        div(c: 'section flag-section')
          ..add([
            h2(text: 'Dart VM Flag List'),
            div(c: 'flag-list-container')
              ..flex()
              ..add(_flagList = div(c: 'flag-list')..layoutVertical()),
          ])
          ..hidden(!serviceManager.connectedApp.isRunningOnDartVM)
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
        div(c: 'info-title', text: title),
        div(c: 'version-value', text: value),
      ]);
    if (includeMargin) versionDisplay.clazz('version-margin');
    return versionDisplay;
  }
}
