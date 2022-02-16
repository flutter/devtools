// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as analytics_constants;
import '../debugger/debugger_controller.dart';
import '../primitives/auto_dispose_mixin.dart';
import '../primitives/blocking_action_mixin.dart';
import '../shared/common_widgets.dart';
import '../shared/connected_app.dart';
import '../shared/error_badge_manager.dart';
import '../shared/globals.dart';
import '../shared/screen.dart';
import '../shared/service_extensions.dart' as extensions;
import '../shared/split.dart';
import '../shared/theme.dart';
import '../shared/utils.dart';
import '../ui/icons.dart';
import '../ui/search.dart';
import '../ui/service_extension_widgets.dart';
import 'inspector_controller.dart';
import 'inspector_screen_details_tab.dart';
import 'inspector_service.dart';
import 'inspector_tree.dart';
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
    with
        BlockingActionMixin,
        AutoDisposeMixin,
        SearchFieldMixin<InspectorScreenBody> {
  InspectorController inspectorController;

  InspectorTreeController get summaryTreeController =>
      inspectorController?.inspectorTree;

  InspectorTreeController get detailsTreeController =>
      inspectorController?.details?.inspectorTree;

  DebuggerController _debuggerController;

  bool searchVisible = false;

  /// Indicates whether search can be closed. The value is set to true when
  /// search target type dropdown is displayed
  /// TODO(https://github.com/flutter/devtools/issues/3489) use this variable when adding the scope dropdown
  bool searchPreventClose = false;

  SearchTargetType searchTarget = SearchTargetType.widget;

  static const summaryTreeKey = Key('Summary Tree');
  static const detailsTreeKey = Key('Details Tree');
  static const minScreenWidthForTextBeforeScaling = 900.0;
  static const unscaledIncludeRefreshTreeWidth = 1255.0;
  static const serviceExtensionButtonsIncludeTextWidth = 1160.0;

  @override
  void dispose() {
    inspectorController.inspectorTree.dispose();
    if (inspectorController.isSummaryTree &&
        inspectorController.details != null) {
      inspectorController.details.inspectorTree.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ga.screen(InspectorScreen.id);

    if (serviceManager.inspectorService == null) {
      // The app must not be a Flutter app.
      return;
    }
    final inspectorTreeController = InspectorTreeController();
    final detailsTree = InspectorTreeController();
    inspectorController = InspectorController(
      inspectorTree: inspectorTreeController,
      detailsTree: detailsTree,
      treeType: FlutterTreeType.widget,
    );

    summaryTreeController.setSearchTarget(searchTarget);

    addAutoDisposeListener(searchFieldFocusNode, () {
      // Close the search once focus is lost and following conditions are met:
      //  1. Search string is empty.
      //  2. [searchPreventClose] == false (this is set true when searchTargetType Dropdown is opened).
      if (!searchFieldFocusNode.hasFocus &&
          summaryTreeController.search.isEmpty &&
          !searchPreventClose) {
        setState(() {
          searchVisible = false;
        });
      }

      // Reset [searchPreventClose] state to false after the search field gains focus.
      // Focus is returned automatically once the Dropdown menu is closed.
      if (searchFieldFocusNode.hasFocus) {
        searchPreventClose = false;
      }
    });
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
      inspectorTreeController: summaryTreeController,
    );

    final splitAxis = Split.axisFor(context, 0.85);
    final widgetTrees = Split(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      children: [
        summaryTree,
        InspectorDetails(
          detailsTree: detailsTree,
          controller: inspectorController,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return OutlineDecoration(
          child: Column(
            children: [
              InspectorSummaryTreeControls(
                isSearchVisible: searchVisible,
                constraints: constraints,
                onRefreshInspectorPressed: _refreshInspector,
                onSearchVisibleToggle: _onSearchVisibleToggle,
                searchFieldBuilder: () => buildSearchField(
                  controller: summaryTreeController,
                  searchFieldKey: GlobalKey(
                    debugLabel: 'inspectorScreenSearch',
                  ),
                  searchFieldEnabled: true,
                  shouldRequestFocus: searchVisible,
                  supportsNavigation: true,
                  onClose: _onSearchVisibleToggle,
                ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: serviceManager.errorBadgeManager
                      .erroredItemsForPage(InspectorScreen.id),
                  builder:
                      (_, LinkedHashMap<String, DevToolsError> errors, __) {
                    final inspectableErrors = errors.map((key, value) =>
                        MapEntry(key, value as InspectableWidgetError));
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
                            valueListenable:
                                inspectorController.selectedErrorIndex,
                            builder: (_, selectedErrorIndex, __) => Positioned(
                              top: 0,
                              right: 0,
                              child: ErrorNavigator(
                                errors: inspectableErrors,
                                errorIndex: selectedErrorIndex,
                                onSelectError:
                                    inspectorController.selectErrorByIndex,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _onSearchVisibleToggle() {
    setState(() {
      searchVisible = !searchVisible;
    });
    summaryTreeController.resetSearch();
    searchTextFieldController.clear();
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

  void _refreshInspector() {
    ga.select(analytics_constants.inspector, analytics_constants.refresh);
    blockWhileInProgress(() async {
      await inspectorController?.onForceRefresh();
    });
  }
}

class InspectorSummaryTreeControls extends StatelessWidget {
  const InspectorSummaryTreeControls({
    Key key,
    @required this.constraints,
    @required this.isSearchVisible,
    @required this.onRefreshInspectorPressed,
    @required this.onSearchVisibleToggle,
    @required this.searchFieldBuilder,
  }) : super(key: key);

  static const _searchBreakpoint = 375.0;

  final bool isSearchVisible;
  final BoxConstraints constraints;
  final VoidCallback onRefreshInspectorPressed;
  final VoidCallback onSearchVisibleToggle;
  final Widget Function() searchFieldBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _controlsContainer(
          context,
          Row(
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: denseSpacing),
                child: Text('Widget Tree'),
              ),
              ...!isSearchVisible
                  ? [
                      const Spacer(),
                      ToolbarAction(
                        icon: Icons.search,
                        onPressed: onSearchVisibleToggle,
                        tooltip: 'Search Tree',
                      ),
                    ]
                  : [
                      constraints.maxWidth >= _searchBreakpoint
                          ? _buildSearchControls()
                          : const Spacer()
                    ],
              ToolbarAction(
                icon: Icons.refresh,
                onPressed: onRefreshInspectorPressed,
                tooltip: 'Refresh Tree',
              ),
            ],
          ),
        ),
        if (isSearchVisible && constraints.maxWidth < _searchBreakpoint)
          _controlsContainer(
            context,
            Row(children: [_buildSearchControls()]),
          ),
      ],
    );
  }

  Container _controlsContainer(BuildContext context, Widget child) {
    return Container(
      height: defaultButtonHeight +
          (isDense() ? denseModeDenseSpacing : denseSpacing),
      decoration: BoxDecoration(
        border: Border(
          bottom: defaultBorderSide(Theme.of(context)),
        ),
      ),
      child: child,
    );
  }

  Widget _buildSearchControls() {
    return Expanded(
      child: Container(
        height: defaultTextFieldHeight,
        child: searchFieldBuilder(),
      ),
    );
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
