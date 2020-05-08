// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../flutter/auto_dispose_mixin.dart';
import '../../flutter/blocking_action_mixin.dart';
import '../../flutter/common_widgets.dart';
import '../../flutter/initializer.dart';
import '../../flutter/octicons.dart';
import '../../flutter/screen.dart';
import '../../flutter/split.dart';
import '../../flutter/theme.dart';
import '../../globals.dart';
import '../../service_extensions.dart' as extensions;
import '../../ui/flutter/label.dart';
import '../../ui/flutter/service_extension_widgets.dart';
import '../inspector_controller.dart';
import '../inspector_service.dart';
import 'inspector_screen_details_tab.dart';
import 'inspector_tree_flutter.dart';

class InspectorScreen extends Screen {
  const InspectorScreen()
      : super(
          'inspector',
          title: 'Flutter Inspector',
          icon: Octicons.deviceMobile,
        );

  @override
  String get docPageId => screenId;

  @override
  Widget build(BuildContext context) {
    final isFlutterApp = serviceManager.connectedApp.isFlutterAppNow;
    final isProfileBuild = serviceManager.connectedApp.isProfileBuildNow;
    if (!isFlutterApp || isProfileBuild) {
      return !isFlutterApp
          ? const DisabledForNonFlutterAppMessage()
          : const DisabledForProfileBuildMessage();
    }
    return const InspectorScreenBody();
  }
}

class InspectorScreenBody extends StatefulWidget {
  const InspectorScreenBody();

  @override
  _InspectorScreenBodyState createState() => _InspectorScreenBodyState();
}

class _InspectorScreenBodyState extends State<InspectorScreenBody>
    with BlockingActionMixin, AutoDisposeMixin {
  bool _expandCollapseSupported = false;
  bool _layoutExplorerSupported = false;
  bool connectionInProgress = false;
  InspectorService inspectorService;

  InspectorController inspectorController;
  InspectorTreeControllerFlutter summaryTreeController;
  InspectorTreeControllerFlutter detailsTreeController;
  bool displayedWidgetTrackingNotice = false;

  bool get enableButtons =>
      actionInProgress == false && connectionInProgress == false;

  @override
  void initState() {
    super.initState();
    // TODO(jacobr): support analytics.
    // ga_platform.setupDimensions();
    autoDispose(
        serviceManager.onConnectionAvailable.listen(_handleConnectionStart));
    if (serviceManager.hasConnection) {
      _handleConnectionStart(serviceManager.service);
    }
    autoDispose(
        serviceManager.onConnectionClosed.listen(_handleConnectionStop));
  }

  @override
  void dispose() {
    inspectorService?.dispose();
    inspectorController?.dispose();
    super.dispose();
  }

  void _onExpandClick() {
    blockWhileInProgress(inspectorController.expandAllNodesInDetailsTree);
  }

  void _onResetClick() {
    blockWhileInProgress(inspectorController.collapseDetailsToSelected);
  }

  @override
  Widget build(BuildContext context) {
    final summaryTree = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).focusColor),
      ),
      child: InspectorTree(
        controller: summaryTreeController,
        isSummaryTree: true,
      ),
    );
    final detailsTree = InspectorTree(
      controller: detailsTreeController,
    );

    final splitAxis = Split.axisFor(context, 0.85);
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder(
              valueListenable: serviceManager.serviceExtensionManager
                  .hasServiceExtensionListener(
                      extensions.toggleSelectWidgetMode.extension),
              builder: (_, selectModeSupported, __) {
                return ServiceExtensionButtonGroup(
                  extensions: [
                    selectModeSupported
                        ? extensions.toggleSelectWidgetMode
                        : extensions.toggleOnDeviceWidgetInspector
                  ],
                  minIncludeTextWidth: 650,
                );
              },
            ),
            const SizedBox(width: denseSpacing),
            Container(
              height: Theme.of(context).buttonTheme.height,
              child: OutlineButton(
                onPressed: _refreshInspector,
                child: const MaterialIconLabel(
                  Icons.refresh,
                  'Refresh Tree',
                  includeTextWidth: 750,
                ),
              ),
            ),
            const Spacer(),
            Row(children: getServiceExtensionWidgets()),
          ],
        ),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: Split(
            axis: splitAxis,
            initialFractions: const [0.40, 0.60],
            children: [
              summaryTree,
              InspectorDetailsTabController(
                detailsTree: detailsTree,
                controller: inspectorController,
                actionButtons: _expandCollapseButtons(),
                layoutExplorerSupported: _layoutExplorerSupported,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> getServiceExtensionWidgets() {
    return [
      ServiceExtensionButtonGroup(
        minIncludeTextWidth: 1050,
        extensions: [extensions.slowAnimations],
      ),
      const SizedBox(width: denseSpacing),
      ServiceExtensionButtonGroup(
        minIncludeTextWidth: 1050,
        extensions: [extensions.debugPaint, extensions.debugPaintBaselines],
      ),
      const SizedBox(width: denseSpacing),
      ServiceExtensionButtonGroup(
        minIncludeTextWidth: 1250,
        extensions: [extensions.repaintRainbow, extensions.debugAllowBanner],
      ),
      // TODO(jacobr): implement TogglePlatformSelector.
      //  TogglePlatformSelector().selector
    ];
  }

  Widget _expandCollapseButtons() {
    if (!_expandCollapseSupported) return null;
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        // Add a semi-transparent background to the
        // expand and collapse buttons so they don't interfere
        // too badly with the tree content when the tree
        // is narrow.
        color: Theme.of(context).scaffoldBackgroundColor.withAlpha(200),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: OutlineButton(
                onPressed: enableButtons ? _onExpandClick : null,
                child: const Text(
                  'Expand all',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Flexible(
              child: OutlineButton(
                onPressed: enableButtons ? _onResetClick : null,
                child: const Text(
                  'Collapse to selected',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _onExpandCollapseSupported() {
    setState(() {
      _expandCollapseSupported = true;
    });
  }

  void _onLayoutExplorerSupported() {
    setState(() {
      _layoutExplorerSupported = true;
    });
  }

  void _handleConnectionStart(VmService service) async {
    setState(() {
      connectionInProgress = true;
    });

    try {
      // Init the inspector service, or return null.
      await ensureInspectorDependencies();
      await ensureInspectorServiceDependencies();
      inspectorService =
          await InspectorService.create(service).catchError((e) => null);
    } finally {
      setState(() {
        connectionInProgress = false;
      });
    }

    if (inspectorService == null) {
      return;
    }

    setState(() {
      inspectorController?.dispose();
      summaryTreeController = InspectorTreeControllerFlutter();
      detailsTreeController = InspectorTreeControllerFlutter();
      inspectorController = InspectorController(
        inspectorTree: summaryTreeController,
        detailsTree: detailsTreeController,
        inspectorService: inspectorService,
        treeType: FlutterTreeType.widget,
        onExpandCollapseSupported: _onExpandCollapseSupported,
        onLayoutExplorerSupported: _onLayoutExplorerSupported,
      );

      // TODO(jacobr): move this notice display to once a day.
      if (!displayedWidgetTrackingNotice) {
        // ignore: unawaited_futures
        inspectorService.isWidgetCreationTracked().then((bool value) {
          if (value) {
            return;
          }

          displayedWidgetTrackingNotice = true;
          // TODO(jacobr): implement showMessage.
          // framework.showMessage(
          //  message: trackWidgetCreationWarning,
          //  screenId: inspectorScreenId,
          //);
        });
      }
    });
  }

  void _handleConnectionStop(dynamic event) {
    inspectorController?.setActivate(false);
    inspectorController?.dispose();
    setState(() {
      inspectorController = null;
    });
  }

  void _refreshInspector() {
    // TODO(jacobr): support analytics.
    // ga.select(ga.inspector, ga.refresh);
    blockWhileInProgress(() async {
      await inspectorController?.onForceRefresh();
    });
  }
}
