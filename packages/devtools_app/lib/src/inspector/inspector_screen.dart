// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../auto_dispose_mixin.dart';
import '../blocking_action_mixin.dart';
import '../common_widgets.dart';
import '../connected_app.dart';
import '../error_badge_manager.dart';
import '../globals.dart';
import '../screen.dart';
import '../service_extensions.dart' as extensions;
import '../split.dart';
import '../theme.dart';
import '../ui/icons.dart';
import '../ui/service_extension_widgets.dart';
import 'inspector_controller.dart';
import 'inspector_screen_details_tab.dart';
import 'inspector_service.dart';
import 'inspector_tree_flutter.dart';

class InspectorScreen extends Screen {
  const InspectorScreen()
      : super.conditional(
          id: id,
          requiresLibrary: flutterLibraryUri,
          requiresDebugBuild: true,
          title: 'Flutter Inspector',
          icon: Octicons.deviceMobile,
        );

  static const id = 'inspector';

  @override
  String get docPageId => screenId;

  @override
  Widget build(BuildContext context) => const InspectorScreenBody();
}

class InspectorScreenBody extends StatefulWidget {
  const InspectorScreenBody();

  @override
  InspectorScreenBodyState createState() => InspectorScreenBodyState();
}

class InspectorScreenBodyState extends State<InspectorScreenBody>
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

  static const summaryTreeKey = Key('Summary Tree');
  static const detailsTreeKey = Key('Details Tree');
  static const includeTextWidth = 900.0;
  static const includeRefreshTreeWidth = 1225.0;
  static const serviceExtensionButtonsIncludeTextWidth = 1150.0;

  @override
  void initState() {
    super.initState();
    ga.screen(InspectorScreen.id);
    autoDispose(
        serviceManager.onConnectionAvailable.listen(_handleConnectionStart));
    if (serviceManager.connectedAppInitialized) {
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
    final summaryTree = _buildSummaryTreeColumn();

    final detailsTree = InspectorTree(
      key: detailsTreeKey,
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
                  .hasServiceExtension(
                      extensions.toggleSelectWidgetMode.extension),
              builder: (_, selectModeSupported, __) {
                return ServiceExtensionButtonGroup(
                  extensions: [
                    selectModeSupported
                        ? extensions.toggleSelectWidgetMode
                        : extensions.toggleOnDeviceWidgetInspector
                  ],
                  minIncludeTextWidth: includeTextWidth,
                );
              },
            ),
            const SizedBox(width: denseSpacing),
            IconLabelButton(
              onPressed: _refreshInspector,
              icon: Icons.refresh,
              label: 'Refresh Tree',
              color: Theme.of(context).colorScheme.serviceExtensionButtonsTitle,
              includeTextWidth: includeRefreshTreeWidth,
            ),
            const Spacer(),
            Row(children: getServiceExtensionWidgets()),
          ],
        ),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: Split(
            axis: splitAxis,
            initialFractions: const [0.33, 0.67],
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

  Widget _buildSummaryTreeColumn() => OutlineDecoration(
        child: ValueListenableBuilder(
          valueListenable: serviceManager.errorBadgeManager
              .erroredItemsForPage(InspectorScreen.id),
          builder: (_, LinkedHashMap<String, DevToolsError> errors, __) {
            final inspectableErrors = errors.map(
                (key, value) => MapEntry(key, value as InspectableWidgetError));
            return Stack(
              children: [
                InspectorTree(
                  key: summaryTreeKey,
                  controller: summaryTreeController,
                  isSummaryTree: true,
                  widgetErrors: inspectableErrors,
                ),
                if (errors.isNotEmpty && inspectorController != null)
                  ValueListenableBuilder(
                    valueListenable: inspectorController.selectedErrorIndex,
                    builder: (_, selectedErrorIndex, __) => Positioned(
                      top: 0,
                      right: 0,
                      child: ErrorNavigator(
                        errors: inspectableErrors,
                        errorIndex: selectedErrorIndex,
                        onSelectError: inspectorController.selectErrorByIndex,
                      ),
                    ),
                  )
              ],
            );
          },
        ),
      );

  List<Widget> getServiceExtensionWidgets() {
    return [
      ServiceExtensionButtonGroup(
        minIncludeTextWidth: serviceExtensionButtonsIncludeTextWidth,
        extensions: [
          extensions.slowAnimations,
          extensions.debugPaint,
          extensions.debugPaintBaselines,
          extensions.repaintRainbow,
          extensions.invertOversizedImages,
        ],
      ),
      // TODO(jacobr): implement TogglePlatformSelector.
      //  TogglePlatformSelector().selector
    ];
  }

  Widget _expandCollapseButtons() {
    if (!_expandCollapseSupported) return null;

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            child: IconLabelButton(
              icon: Icons.unfold_more,
              onPressed: enableButtons ? _onExpandClick : null,
              label: 'Expand all',
              includeTextWidth: includeTextWidth,
            ),
          ),
          const SizedBox(width: denseSpacing),
          SizedBox(
            child: IconLabelButton(
              icon: Icons.unfold_less,
              onPressed: enableButtons ? _onResetClick : null,
              label: 'Collapse to selected',
              includeTextWidth: includeTextWidth,
            ),
          )
        ],
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

      // Clear any existing badge/errors for older errors that were collected.
      serviceManager.errorBadgeManager.clearErrors(InspectorScreen.id);
      inspectorController.filterErrors();

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
    ga.select(analytics_constants.inspector, analytics_constants.refresh);
    blockWhileInProgress(() async {
      await inspectorController?.onForceRefresh();
    });
  }
}

class ErrorNavigator extends StatelessWidget {
  const ErrorNavigator({
    Key key,
    @required this.errors,
    @required this.errorIndex,
    @required this.onSelectError,
  }) : super(key: key);

  final LinkedHashMap<String, InspectableWidgetError> errors;

  final int errorIndex;

  final Function(int) onSelectError;

  @override
  Widget build(BuildContext context) {
    final label = errorIndex != null
        ? 'Error ${errorIndex + 1}/${errors.length}'
        : 'Errors: ${errors.length}';
    return Container(
      color: devtoolsError,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: defaultSpacing,
          vertical: denseSpacing,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: denseSpacing),
              child: Text(label),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: defaultIconSize,
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: _previousError,
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: defaultIconSize,
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _nextError,
            ),
          ],
        ),
      ),
    );
  }

  void _previousError() {
    var newIndex = errorIndex == null ? errors.length - 1 : errorIndex - 1;
    while (newIndex < 0) {
      newIndex += errors.length;
    }

    onSelectError(newIndex);
  }

  void _nextError() {
    final newIndex = errorIndex == null ? 0 : (errorIndex + 1) % errors.length;

    onSelectError(newIndex);
  }
}
