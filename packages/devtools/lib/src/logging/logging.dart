// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:split/split.dart' as split;

import '../framework/framework.dart';
import '../inspector/inspector.dart';
import '../inspector/inspector_service.dart';
import '../inspector/inspector_tree.dart';
import '../inspector/inspector_tree_html.dart';
import '../inspector/inspector_tree_web.dart';
import '../service_extensions.dart';
import '../tables.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/primer.dart';
import '../ui/service_extension_elements.dart';
import '../ui/ui_utils.dart';
import 'logging_controller.dart';

class LoggingScreen extends Screen {
  LoggingScreen()
      : super(name: 'Logging', id: 'logging', iconClass: 'octicon-clippy') {
    logCountStatus = StatusItem();
    logCountStatus.element.text = '';
    addStatusItem(logCountStatus);
    controller = LoggingController(
      isVisible: () => visible,
      onLogCountStatusChanged: (status) {
        logCountStatus.element.text = status;
      },
    );
  }

  Table<LogData> _loggingTable;

  LoggingController controller;
  LogDetailsUI logDetailsUI;
  StatusItem logCountStatus;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    this.framework = framework;

    _loggingTable = _createTableView();
    _loggingTable.element
      ..layoutHorizontal()
      ..clazz('section')
      ..clazz('full-size')
      ..clazz('log-summary');
    // TODO(devoncarew): Add checkbox toggles to enable specific logging channels.

    logDetailsUI = LogDetailsUI();

    screenDiv.add(<CoreElement>[
      div(c: 'section')
        ..add(<CoreElement>[
          form()
            ..clazz('align-items-center')
            ..layoutHorizontal()
            ..add(<CoreElement>[
              PButton('Clear logs')
                ..small()
                ..click(() {
                  ga.select(ga.logging, ga.clearLogs);
                  controller.clear();
                }),
              div()..flex(),
              ServiceExtensionCheckbox(structuredErrors).element,
            ])
        ]),
      div(c: 'section log-area bidirectional')
        ..flex()
        ..add(<CoreElement>[
          _loggingTable.element,
          logDetailsUI,
        ]),
    ]);

    controller.loggingTableModel = _loggingTable.model;
    controller.detailsController = LoggingDetailsController(
      onShowInspector: () {
        framework.navigateTo(inspectorScreenId);
      },
      onShowDetails: logDetailsUI.onShowDetails,
      createLoggingTree: logDetailsUI.createLoggingTree,
    );
    return screenDiv;
  }

  bool _firstEnter = true;

  @override
  void entering() {
    if (_firstEnter) {
      // configure the table / details splitter. Setting up this splitter works
      // better once the UI is active in the DOM so we have to delay it until
      // we get the entering event.
      // TODO(devoncarew): Use fixedSplitBidirectional when we move to
      // package:split v0.0.4.
      split.flexSplit(
        [_loggingTable.element.element, logDetailsUI.element],
        gutterSize: defaultSplitterWidth,
        horizontal: false,
        sizes: [70, 30],
        minSize: [200, 200],
      );
      _firstEnter = false;
    }
    controller.entering();
  }

  Table<LogData> _createTableView() {
    final table = Table<LogData>.virtual();
    table.model
      ..addColumn(LogWhenColumn())
      ..addColumn(LogKindColumn())
      ..addColumn(LogMessageColumn());
    return table;
  }
}

// TODO(jacobr): refactor this code to have a cleaner view-controller
// separation.
class LogDetailsUI extends CoreElement {
  LogDetailsUI() : super('div', classes: 'full-size') {
    layoutVertical();

    add(<CoreElement>[
      content = div(c: 'log-details table-border')
        ..flex()
        ..add(message = div(c: 'pre-wrap monospace')),
    ]);
  }

  CoreElement content;
  CoreElement message;

  void onShowDetails({String text, InspectorTree tree}) {
    // Reset the vertical scroll value if any.
    content.element.scrollTop = 0;
    message.clear();
    if (text != null) {
      message.text = text;
    }
    if (tree != null) {
      message.add((tree as InspectorTreeWeb).element);
    }
  }

  InspectorTreeWeb createLoggingTree({VoidCallback onSelectionChange}) {
    return InspectorTreeHtml(
      summaryTree: false,
      treeType: FlutterTreeType.widget,
      onHover: (node, icon) {
        element.style.cursor = (node?.diagnostic?.isDiagnosticableValue == true)
            ? 'pointer'
            : 'auto';
      },
      onSelectionChange: onSelectionChange,
    );
  }
}
