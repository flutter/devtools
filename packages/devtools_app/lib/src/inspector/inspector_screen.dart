// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../auto_dispose_mixin.dart';
import '../blocking_action_mixin.dart';
import '../common_widgets.dart';
import '../connected_app.dart';
import '../debugger/debugger_controller.dart';
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
import 'inspector_tree_controller.dart';

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

  // There is not enough room to safely show the console in the embed view of
  // the DevTools and IDEs have their own consoles.
  @override
  bool showConsole(bool embed) => !embed;

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

  InspectorController inspectorController;

  InspectorTreeController get summaryTreeController =>
      inspectorController?.inspectorTree;

  InspectorTreeController get detailsTreeController =>
      inspectorController?.details?.inspectorTree;

  DebuggerController _debuggerController;

  bool get enableButtons => actionInProgress == false;

  static const summaryTreeKey = Key('Summary Tree');
  static const detailsTreeKey = Key('Details Tree');
  static const minScreenWidthForTextBeforeScaling = 900.0;
  static const unscaledIncludeRefreshTreeWidth = 1255.0;
  static const serviceExtensionButtonsIncludeTextWidth = 1160.0;

  @override
  void initState() {
    super.initState();
    ga.screen(InspectorScreen.id);

    if (serviceManager.inspectorService == null) {
      // The app must not be a Flutter app.
      return;
    }
    inspectorController = InspectorController(
      inspectorTree: InspectorTreeController(),
      detailsTree: InspectorTreeController(),
      treeType: FlutterTreeType.widget,
      onExpandCollapseSupported: _onExpandCollapseSupported,
      onLayoutExplorerSupported: _onLayoutExplorerSupported,
    );
  }

  void _onExpandClick() {
    blockWhileInProgress(inspectorController.expandAllNodesInDetailsTree);
  }

  void _onResetClick() {
    blockWhileInProgress(inspectorController.collapseDetailsToSelected);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _debuggerController = Provider.of<DebuggerController>(context);
  }

  @override
  Widget build(BuildContext context) {
    final summaryTree = _buildSummaryTreeColumn(_debuggerController);

    final detailsTree = InspectorTree(
      key: detailsTreeKey,
      controller: detailsTreeController,
      debuggerController: _debuggerController,
    );

    final splitAxis = Split.axisFor(context, 0.85);
    final widgetTrees = Split(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      fractionsKey: 'inspector_detail_tree',
      children: [
        summaryTree,
        InspectorDetailsTabController(
          detailsTree: detailsTree,
          controller: inspectorController,
          actionButtons: _expandCollapseButtons(),
          layoutExplorerSupported: _layoutExplorerSupported,
        ),
      ],
    );
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
                  minScreenWidthForTextBeforeScaling:
                      minScreenWidthForTextBeforeScaling,
                );
              },
            ),
            const SizedBox(width: denseSpacing),
            IconLabelButton(
              onPressed: _refreshInspector,
              icon: Icons.refresh,
              label: 'Refresh Tree',
              color: Theme.of(context).colorScheme.toggleButtonsTitle,
              minScreenWidthForTextBeforeScaling:
                  unscaledIncludeRefreshTreeWidth,
            ),
            const Spacer(),
            Row(children: getServiceExtensionWidgets()),
          ],
        ),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: widgetTrees,
        ),
      ],
    );
  }

  Widget _buildSummaryTreeColumn(
    DebuggerController debuggerController,
  ) {
    return OutlineDecoration(
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
                debuggerController: debuggerController,
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
  }

  List<Widget> getServiceExtensionWidgets() {
    return [
      ServiceExtensionButtonGroup(
        minScreenWidthForTextBeforeScaling:
            serviceExtensionButtonsIncludeTextWidth,
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
              minScreenWidthForTextBeforeScaling:
                  minScreenWidthForTextBeforeScaling,
            ),
          ),
          const SizedBox(width: denseSpacing),
          SizedBox(
            child: IconLabelButton(
              icon: Icons.unfold_less,
              onPressed: enableButtons ? _onResetClick : null,
              label: 'Collapse to selected',
              minScreenWidthForTextBeforeScaling:
                  minScreenWidthForTextBeforeScaling,
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
