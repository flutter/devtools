// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library inspector;

import 'dart:async';

import 'package:vm_service_lib/vm_service_lib.dart';

import '../framework/framework.dart';
import '../globals.dart';
import '../service_extensions.dart' as extensions;
import '../ui/custom.dart';
import '../ui/elements.dart';
import '../ui/icons.dart';
import '../ui/primer.dart';
import '../ui/split.dart';
import '../ui/ui_utils.dart';
import 'inspector_controller.dart';
import 'inspector_service.dart';
import 'inspector_tree_canvas.dart';
import 'inspector_tree_html.dart';
import 'inspector_tree_web.dart';

// Generally the canvas tree renderer is a better fit for the inspector.
// The html renderer is more appropriate for small static trees such as those
// generated in the logging view.
bool _useHtmlInspectorTreeRenderer = false;

// TODO(jacobr): add UI to view and configure the pub root directory.

class InspectorScreen extends Screen {
  InspectorScreen()
      : super(
          name: 'Inspector',
          id: 'inspector',
          iconClass: 'octicon-device-mobile',
        );

  PButton refreshTreeButton;

  SetStateMixin inspectorStateMixin = SetStateMixin();
  InspectorService inspectorService;
  InspectorController inspectorController;
  ProgressElement progressElement;
  CoreElement inspectorContainer;
  StreamSubscription<Object> splitterSubscription;
  bool displayedWidgetTrackingNotice = false;

  @override
  CoreElement createContent(Framework framework) {
    final CoreElement screenDiv = div(c: 'custom-scrollbar')..layoutVertical();

    final CoreElement buttonSection = div(c: 'section')
      ..layoutHorizontal()
      ..add(<CoreElement>[
        div(c: 'btn-group')
          ..add([
            ServiceExtensionButton(
              extensions.toggleSelectWidgetMode,
            ).button,
            refreshTreeButton =
                PButton.icon('Refresh Tree', FlutterIcons.forceRefresh)
                  ..small()
                  ..disabled = true
                  ..click(_refreshInspector),
          ]),
        progressElement = ProgressElement()
          ..clazz('margin-left')
          ..display = 'none',
        div()..flex(),
      ]);
    getServiceExtensionButtons().forEach(buttonSection.add);

    screenDiv.add(<CoreElement>[
      buttonSection,
      inspectorContainer = div(c: 'inspector-container'),
    ]);

    serviceManager.onConnectionAvailable.listen(_handleConnectionStart);
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    serviceManager.onConnectionClosed.listen(_handleConnectionStop);

    return screenDiv;
  }

  @override
  void exiting() {
    framework.clearMessages();
  }

  void _handleConnectionStart(VmService service) async {
    refreshTreeButton.disabled = false;

    final Spinner spinner = Spinner()..clazz('padded');
    inspectorContainer.add(spinner);

    try {
      await ensureInspectorServiceDependencies();

      // Init the inspector service, or return null.
      inspectorService =
          await InspectorService.create(service).catchError((e) => null);
      final pubRootDirectory =
          await inspectorService?.inferPubRootDirectoryIfNeeded();
      if (pubRootDirectory != null) {
        // TODO(jacobr): add ui to view and set a different pub root directory and
        // display the pub root directory in the status bar.
      }
    } finally {
      spinner.element.remove();
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
    );
    final InspectorTreeWeb inspectorTree = inspectorController.inspectorTree;
    final InspectorTreeWeb detailsInspectorTree =
        inspectorController.details.inspectorTree;

    final elements = [
      inspectorTree.element.element,
      detailsInspectorTree.element.element
    ];
    inspectorContainer.add(elements);
    splitterSubscription = flexSplitBidirectional(
      elements,
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

        framework.showWarning(
            '''The widget creation tracking feature is not enabled (this is
required for advanced Flutter Inspector functionality).

To fix this relaunch your application by running 'flutter run
--track-widget-creation' or run your application from VS Code or IntelliJ.''');
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
    refreshTreeButton.disabled = true;
    await inspectorController?.onForceRefresh();
    refreshTreeButton.disabled = false;
  }
}
