// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../analytics/analytics_stub.dart'
    if (dart.library.html) '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart';
import '../auto_dispose_mixin.dart';
import '../blocking_action_mixin.dart';
import '../common_widgets.dart';
import '../connected_app.dart';
import '../error_badge_manager.dart';
import '../globals.dart';
import '../octicons.dart';
import '../screen.dart';
import '../service_extensions.dart' as extensions;
import '../split.dart';
import '../theme.dart';
import '../ui/service_extension_widgets.dart';
import 'inspector_controller.dart';
import 'inspector_screen_details_tab.dart';
import 'inspector_service.dart';
import 'inspector_tree.dart';
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

  // The index of the current selected error, or null if no error is selected.
  int _selectedErrorIndex;

  @override
  void initState() {
    super.initState();
    ga.screen(InspectorScreen.id);
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
    final treeColumn = ValueListenableBuilder<
            LinkedHashMap<String, DevToolsError>>(
        valueListenable: serviceManager.errorBadgeManager
            .erroredWidgetNotifier(InspectorScreen.id),
        builder: (context, _errors, _) {
          final errors = _errors.map(
              (key, value) => MapEntry(key, value as InspectableWidgetError));
          final errorList = errors.values.toList();

          final _selectError = (int index) => setState(() {
                _selectedErrorIndex = index;
                inspectorController.updateSelectionFromService(
                    firstFrame: false,
                    inspectorRef: errorList[index].inspectorRef);
              });

          final summaryTree = Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).focusColor),
            ),
            child: Stack(
              children: [
                InspectorTree(
                  controller: summaryTreeController,
                  isSummaryTree: true,
                  widgetErrors: errors,
                ),
                if (errors.isNotEmpty)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _ErrorOverlay(
                      selectedErrorIndex: _selectedErrorIndex,
                      errors: errorList,
                      onSelectedErrorIndexChanged: _selectError,
                    ),
                  ),
              ],
            ),
          );

          return errors.isEmpty
              ? summaryTree
              : Split(
                  axis: Axis.vertical,
                  initialFractions: const [0.8, 0.2],
                  children: [
                    summaryTree,
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).focusColor),
                      ),
                      child: _ErrorList(
                        selectedErrorIndex: _selectedErrorIndex,
                        errors: errorList,
                        onSelectedErrorIndexChanged: _selectError,
                      ),
                    )
                  ],
                );
        });

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
                  .hasServiceExtension(
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
            IconLabelButton(
              onPressed: _refreshInspector,
              icon: Icons.refresh,
              label: 'Refresh Tree',
              includeTextWidth: 750,
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
              treeColumn,
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
        extensions: [
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
          Flexible(
            child: FixedHeightOutlinedButton(
              onPressed: enableButtons ? _onExpandClick : null,
              child: const Text(
                'Expand all',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: denseSpacing),
          Flexible(
            child: FixedHeightOutlinedButton(
              onPressed: enableButtons ? _onResetClick : null,
              child: const Text(
                'Collapse to selected',
                overflow: TextOverflow.ellipsis,
              ),
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
    ga.select(inspector, refresh);
    blockWhileInProgress(() async {
      await inspectorController?.onForceRefresh();
    });
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay(
      {Key key,
      @required this.selectedErrorIndex,
      @required this.errors,
      @required this.onSelectedErrorIndexChanged})
      : super(key: key);

  final int selectedErrorIndex;
  final List<InspectableWidgetError> errors;
  final void Function(int) onSelectedErrorIndexChanged;

  @override
  Widget build(BuildContext context) {
    final label = selectedErrorIndex != null
        ? 'Errors: ${selectedErrorIndex + 1}/${errors.length}'
        : 'Errors: ${errors.length}';
    return Container(
      color: devtoolsError,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          children: [
            Text(label),
            IconButton(
              padding: const EdgeInsets.all(0.0),
              icon: const Icon(Icons.chevron_left),
              onPressed: _previousError,
            ),
            IconButton(
              padding: const EdgeInsets.all(0.0),
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextError,
            ),
          ],
        ),
      ),
    );
  }

  void _previousError() {
    var newIndex = errors.isEmpty
        ? null
        : selectedErrorIndex == null
            ? errors.length - 1
            : selectedErrorIndex - 1;
    while (newIndex < 0) {
      newIndex += errors.length;
    }
    onSelectedErrorIndexChanged(newIndex);
  }

  void _nextError() {
    final newIndex = errors.isEmpty
        ? null
        : selectedErrorIndex == null
            ? 0
            : (selectedErrorIndex + 1) % errors.length;
    onSelectedErrorIndexChanged(newIndex);
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList(
      {Key key,
      @required this.errors,
      @required this.selectedErrorIndex,
      @required this.onSelectedErrorIndexChanged})
      : super(key: key);

  final int selectedErrorIndex;
  final List<InspectableWidgetError> errors;
  final void Function(int) onSelectedErrorIndexChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: errors.length,
      itemBuilder: (context, index) {
        final error = errors[index];
        return Container(
          color: index == selectedErrorIndex
              ? colorScheme.selectedRowBackgroundColor
              : null,
          child: Padding(
            padding: const EdgeInsets.all((rowHeight - defaultIconSize) / 2),
            child: InkWell(
              onTap: () => onSelectedErrorIndexChanged(index),
              child: Row(
                children: [
                  CustomPaint(
                    size: const Size(0, defaultIconSize),
                    painter: BadgePainter(number: index + 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: rowHeight, right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      decoration: BoxDecoration(
                        color: devtoolsError,
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                      child: const Text(
                        'error',
                        overflow: TextOverflow.ellipsis,
                        // style: textStyle,
                      ),
                    ),
                  ),
                  Text(error.errorMessage)
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
