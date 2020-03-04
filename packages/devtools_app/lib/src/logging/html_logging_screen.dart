// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansi_up/ansi_up.dart';
import 'package:split/split.dart' as split;
import '../framework/html_framework.dart';
import '../globals.dart';
import '../html_tables.dart';
import '../inspector/html_inspector_screen.dart';
import '../inspector/inspector_service.dart';
import '../inspector/inspector_tree.dart';
import '../inspector/inspector_tree_html.dart';
import '../inspector/inspector_tree_web.dart';
import '../service_extensions.dart';
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/fake_flutter/fake_flutter.dart';
import '../ui/html_elements.dart';
import '../ui/primer.dart';
import '../ui/service_extension_elements.dart';
import '../ui/ui_utils.dart';

import 'logging_controller.dart';

class HtmlLoggingScreen extends HtmlScreen {
  HtmlLoggingScreen()
      : super(name: 'Logging', id: 'logging', iconClass: 'octicon-clippy') {
    logCountStatus = HtmlStatusItem();
    logCountStatus.element.text = '';
    addStatusItem(logCountStatus);
    controller = LoggingController(
      isVisible: () => visible,
      onLogCountStatusChanged: (status) {
        logCountStatus.element.text = status;
      },
    );
  }

  HtmlTable<LogData> _loggingTable;

  LoggingController controller;
  HtmlLogDetails logDetailsUI;
  HtmlStatusItem logCountStatus;

  @override
  CoreElement createContent(HtmlFramework framework) {
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

    logDetailsUI = HtmlLogDetails();

    // Enable structured errors by default as soon as the user opens the
    // logging page.
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      structuredErrors.extension,
      true,
      true,
    );

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

  @override
  void onContentAttached() {
    split.fixedSplitBidirectional(
      [_loggingTable.element.element, logDetailsUI.element],
      gutterSize: defaultSplitterWidth,
      horizontalSizes: [60, 40],
      verticalSizes: [70, 30],
      minSize: [200, 200],
    );
  }

  @override
  void entering() {
    controller.entering();
  }

  HtmlTable<LogData> _createTableView() {
    final table = HtmlTable<LogData>.virtual();
    table.model
      ..addColumn(LogWhenColumn())
      ..addColumn(LogKindColumn())
      ..addColumn(LogMessageColumn(logMessageToHtml));
    return table;
  }
}

// TODO(jacobr): refactor this code to have a cleaner view-controller
// separation.
class HtmlLogDetails extends CoreElement {
  HtmlLogDetails() : super('div', classes: 'full-size') {
    layoutVertical();

    add(<CoreElement>[
      content = div(c: 'log-details table-border')
        ..flex()
        ..add(message = div(c: 'pre-wrap monospace')),
    ]);
  }

  CoreElement content;
  CoreElement message;

  void onShowDetails({String text, InspectorTreeController tree}) {
    // Reset the vertical scroll value if any.
    content.element.scrollTop = 0;
    message.clear();
    if (text != null) {
      message.setInnerHtml(logMessageToHtml(text));
    }
    if (tree != null) {
      message.add((tree as InspectorTreeWeb).element);
    }
  }

  InspectorTreeWeb createLoggingTree({VoidCallback onSelectionChange}) {
    final tree = InspectorTreeHtml();
    tree.config = InspectorTreeConfig(
      summaryTree: false,
      onNodeAdded: null,
      treeType: FlutterTreeType.widget,
      onHover: (node, icon) {
        element.style.cursor = (node?.diagnostic?.isDiagnosticableValue == true)
            ? 'pointer'
            : 'auto';
      },
      onSelectionChange: onSelectionChange,
    );
    return tree;
  }
}

String logMessageToHtml(String message) {
  return (div()..add(logMessageToElements(message))).element.innerHtml;
}

Iterable<CoreElement> logMessageToElements(String message) sync* {
  // We build up the log message using the DOM rather than string concatenation
  // to avoid XSS attacks.
  for (var part in decodeAnsiColorEscapeCodes(message, AnsiUp())) {
    final style = part.style;

    final element = part.url != null
        ? a(text: part.text, href: part.url, target: '_blank;')
        : span(text: part.text);
    if (style?.isNotEmpty ?? false) {
      element.element.setAttribute('style', style);
    }
    yield element;
  }
}
