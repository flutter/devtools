// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library inspector;

import 'dart:async';
import 'package:html_shim/html.dart' show Element;
import 'package:html_shim/html.dart' as html;

import 'package:split/split.dart';
import 'package:vm_service/vm_service.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../messages.dart';
import '../service_extensions.dart' as extensions;
import '../ui/analytics.dart' as ga;
import '../ui/analytics_platform.dart' as ga_platform;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/service_extension_elements.dart';
import '../ui/ui_utils.dart';
import 'inspector_controller.dart';
import 'inspector_service.dart';
import 'inspector_tree_canvas.dart';
import 'inspector_tree_html.dart';
import 'inspector_tree_web.dart';

const inspectorScreenId = 'inspector';

// Generally the canvas tree renderer is a better fit for the inspector.
// The html renderer is more appropriate for small static trees such as those
// generated in the logging view.
bool _useHtmlInspectorTreeRenderer = false;

// TODO(jacobr): add UI to view and configure the pub root directory.

class InspectorScreen extends Screen {
  InspectorScreen({bool enabled, String disabledTooltip})
      : super(
          name: 'Flutter Inspector',
          id: inspectorScreenId,
          iconClass: 'octicon-device-mobile',
          enabled: enabled,
          disabledTooltip: disabledTooltip,
        );

  PButton refreshTreeButton;

  SetStateMixin inspectorStateMixin = SetStateMixin();

  InspectorService inspectorService;

  InspectorController inspectorController;

  ProgressElement progressElement;

  CoreElement inspectorContainer;

  CoreElement expandCollapseButtonGroup;

  StreamSubscription<Object> splitterSubscription;

  bool displayedWidgetTrackingNotice = false;

  @override
  CoreElement createContent(Framework framework) {
    ga_platform.setupDimensions();

    final CoreElement screenDiv = div(c: 'custom-scrollbar inspector-page')
      ..layoutVertical();

    final CoreElement buttonSection = div(c: 'section')
      ..layoutHorizontal()
      ..add(<CoreElement>[
        div(c: 'btn-group collapsible-750 nowrap')
          ..add([
            ServiceExtensionButton(
              extensions.toggleSelectWidgetMode,
            ).button,
            refreshTreeButton =
                PButton.icon('Refresh Tree', FlutterIcons.refresh)
                  ..small()
                  ..disabled = true
                  ..click(_refreshInspector),
          ]),
        progressElement = ProgressElement()
          ..clazz('margin-left')
          ..display = 'none',
        div()..flex(),
      ]);
    getServiceExtensionElements().forEach(buttonSection.add);

    final expandButton = PButton('Expand all')..small();
    expandButton.click(() async {
      expandButton.disabled = true;
      await inspectorController.expandAllNodesInDetailsTree();
      expandButton.disabled = false;
    });

    final resetButton = PButton('Collapse to selected')..small();
    resetButton.click(() {
      resetButton.disabled = true;
      inspectorController.collapseDetailsToSelected();
      resetButton.disabled = false;
    });

    expandCollapseButtonGroup = div(c: 'btn-group')
      ..add([expandButton, resetButton])
      ..hidden(true);

    screenDiv.add(<CoreElement>[
      buttonSection,
      inspectorContainer = div(c: 'inspector-container bidirectional'),
    ]);

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

    return screenDiv;
  }

  void _handleConnectionStart(VmService service) async {
    refreshTreeButton.disabled = false;

    final Spinner spinner = Spinner.centered();
    inspectorContainer.add(spinner);

    try {
      await ensureInspectorServiceDependencies();

      // Init the inspector service, or return null.
      inspectorService =
          await InspectorService.create(service).catchError((e) => null);
    } finally {
      spinner.remove();
      refreshTreeButton.disabled = false;
    }

    if (inspectorService == null) {
      return;
    }

    // TODO(jacobr): support the Render tree, Layer tree, and Semantic trees as
    // well as the widget tree.

    inspectorController = InspectorController(
      inspectorTreeFactory: ({
        summaryTree,
        treeType,
        onNodeAdded,
        onSelectionChange,
        onExpand,
        onHover,
      }) {
        if (_useHtmlInspectorTreeRenderer) {
          return InspectorTreeHtml(
            summaryTree: summaryTree,
            treeType: treeType,
            onNodeAdded: onNodeAdded,
            onSelectionChange: onSelectionChange,
            onExpand: onExpand,
            onHover: onHover,
          );
        }
        return InspectorTreeCanvas(
          summaryTree: summaryTree,
          treeType: treeType,
          onNodeAdded: onNodeAdded,
          onSelectionChange: onSelectionChange,
          onExpand: onExpand,
          onHover: onHover,
        );
      },
      inspectorService: inspectorService,
      treeType: FlutterTreeType.widget,
      onExpandCollapseSupported: _onExpandCollapseSupported,
    );
    final InspectorTreeWeb inspectorTree = inspectorController.inspectorTree;
    final InspectorTreeWeb detailsInspectorTree =
        inspectorController.details.inspectorTree;

    final elements = <Element>[
      inspectorTree.element.element,
      detailsInspectorTree.element.element
    ];
    inspectorContainer.add(elements);
    splitterSubscription = flexSplitBidirectional(
      html.toDartHtmlElementList(elements),
      gutterSize: defaultSplitterWidth,
      // When we have two columns we want the details tree to be wider.
      horizontalSizes: [35, 65],
      // When we have two rows we want the main tree to be taller.
      verticalSizes: [60, 40],
    );

    // TODO(jacobr): update visibility based on whether the screen is visible.
    // That will reduce memory usage on the device running a Flutter application
    // when the inspector panel is not visible.
    inspectorController.setVisibleToUser(true);
    inspectorController.setActivate(true);

    // TODO(devoncarew): Move this notice display to once a day.
    if (!displayedWidgetTrackingNotice) {
      // ignore: unawaited_futures
      inspectorService.isWidgetCreationTracked().then((bool value) {
        if (value) {
          return;
        }

        displayedWidgetTrackingNotice = true;
        framework.showMessage(
          message: trackWidgetCreationWarning,
          screenId: inspectorScreenId,
        );
      });
    }
  }

  void _handleConnectionStop(dynamic event) {
    refreshTreeButton.disabled = true;

    inspectorController?.setActivate(false);
    inspectorController?.dispose();
    inspectorController = null;

    splitterSubscription?.cancel();
    splitterSubscription = null;
  }

  void _refreshInspector() async {
    ga.select(ga.inspector, ga.refresh);
    refreshTreeButton.disabled = true;
    await inspectorController?.onForceRefresh();
    refreshTreeButton.disabled = false;
  }

  void _onExpandCollapseSupported() {
    final InspectorTreeWeb detailsInspectorTree =
        inspectorController.details.inspectorTree;

    // Show the expand collapse buttons on initial load if the details tree is
    // not empty.
    if (detailsInspectorTree.selection != null) {
      expandCollapseButtonGroup.hidden(false);
    }
    // Ensure the expand collapse buttons are visible if we have a
    // selected node.
    inspectorController.details.onTreeNodeSelected.listen((_) {
      expandCollapseButtonGroup.hidden(false);
    });

    final currentChild =
        CoreElement.from(detailsInspectorTree.element.element.children.first);
    detailsInspectorTree.element
      ..clear()
      ..add([
        div(c: 'expand-collapse-container')
          ..layoutHorizontal()
          ..add([
            div()..flex(),
            expandCollapseButtonGroup,
          ]),
        // Add negative margin to offset height of expand/reset button group.
        currentChild..clazz('expand-collapse-offset'),
      ]);
  }
}
