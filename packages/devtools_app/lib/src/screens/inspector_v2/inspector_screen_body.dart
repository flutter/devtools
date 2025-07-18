// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/analytics/metrics.dart';
import '../../shared/console/eval/inspector_tree_v2.dart';
import '../../shared/globals.dart';
import '../../shared/managers/banner_messages.dart';
import '../../shared/managers/error_badge_manager.dart';
import '../../shared/primitives/blocking_action_mixin.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils/utils.dart';
import '../inspector_shared/inspector_controls.dart';
import '../inspector_shared/inspector_screen.dart';
import 'inspector_controller.dart';
import 'inspector_tree_controller.dart';
import 'widget_details.dart';

class InspectorScreenBody extends StatefulWidget {
  const InspectorScreenBody({super.key, required this.controller});

  final InspectorController controller;

  @override
  InspectorScreenBodyState createState() => InspectorScreenBodyState();
}

class InspectorScreenBodyState extends State<InspectorScreenBody>
    with BlockingActionMixin, AutoDisposeMixin {
  InspectorController get controller => widget.controller;

  InspectorTreeController get _inspectorTreeController =>
      controller.inspectorTree;

  bool searchVisible = false;

  SearchControllerMixin get searchController => _inspectorTreeController;

  /// Indicates whether search can be closed. The value is set to true when
  /// search target type dropdown is displayed
  /// TODO(https://github.com/flutter/devtools/issues/3489) use this variable when adding the scope dropdown
  bool searchPreventClose = false;

  SearchTargetType searchTarget = SearchTargetType.widget;

  static const inspectorTreeKey = Key('Inspector Tree');
  static const minScreenWidthForText = 900.0;

  static const _welcomeShownStorageId = 'inspectorV2WelcomeShown';

  @override
  void initState() {
    super.initState();
    ga.screen(InspectorScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (serviceConnection.inspectorService == null) {
      // The app must not be a Flutter app.
      return;
    }

    cancelListeners();
    searchVisible = searchController.search.isNotEmpty;
    addAutoDisposeListener(searchController.searchFieldFocusNode, () {
      final searchFieldFocusNode = searchController.searchFieldFocusNode;
      if (searchFieldFocusNode == null) return;
      // Close the search once focus is lost and following conditions are met:
      //  1. Search string is empty.
      //  2. [searchPreventClose] == false (this is set true when searchTargetType Dropdown is opened).
      if (!searchFieldFocusNode.hasFocus &&
          searchController.search.isEmpty &&
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
    addAutoDisposeListener(preferences.inspector.pubRootDirectories, () {
      if (serviceConnection.serviceManager.connectedState.value.connected &&
          controller.firstInspectorTreeLoadCompleted) {
        safeUnawaited(controller.refreshInspector());
      }
    });

    if (!controller.firstInspectorTreeLoadCompleted) {
      ga.timeStart(InspectorScreen.id, gac.pageReady);
    }

    _inspectorTreeController.setSearchTarget(searchTarget);

    unawaited(
      _maybeShowWelcomeMessage(context).catchError((_) {
        // Ignore errors.
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inspectorTree = _buildInspectorTreeColumn();

    final splitAxis = SplitPane.axisFor(context, 0.85);
    final widgetTrees = SplitPane(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      children: [
        inspectorTree,
        WidgetDetails(controller: controller),
      ],
    );
    return Column(
      children: <Widget>[
        InspectorControls(controller: controller),
        const SizedBox(height: intermediateSpacing),
        Expanded(child: widgetTrees),
      ],
    );
  }

  Widget _buildInspectorTreeColumn() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RoundedOutlinedBorder(
          child: Column(
            children: [
              InspectorTreeControls(
                isSearchVisible: searchVisible,
                constraints: constraints,
                onRefreshInspectorPressed: _manualInspectorRefresh,
                onSearchVisibleToggle: _onSearchVisibleToggle,
                searchFieldBuilder: () =>
                    StatelessSearchField<InspectorTreeRow>(
                      controller: _inspectorTreeController,
                      searchFieldEnabled: true,
                      shouldRequestFocus: searchVisible,
                      supportsNavigation: true,
                      onClose: _onSearchVisibleToggle,
                    ),
              ),
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: serviceConnection.errorBadgeManager
                      .erroredItemsForPage(InspectorScreen.id),
                  builder: (_, LinkedHashMap<String, DevToolsError> errors, _) {
                    final inspectableErrors =
                        errors.map(
                              (key, value) => MapEntry(
                                key,
                                value as InspectableWidgetError,
                              ),
                            )
                            as LinkedHashMap<String, InspectableWidgetError>;
                    return Stack(
                      children: [
                        InspectorTree(
                          key: inspectorTreeKey,
                          controller: controller,
                          treeController: _inspectorTreeController,
                          widgetErrors: inspectableErrors,
                          screenId: InspectorScreen.id,
                        ),
                        if (errors.isNotEmpty)
                          ValueListenableBuilder<int?>(
                            valueListenable: controller.selectedErrorIndex,
                            builder: (_, selectedErrorIndex, _) => Positioned(
                              top: 0,
                              right: 0,
                              child: ErrorNavigator(
                                errors: inspectableErrors,
                                errorIndex: selectedErrorIndex,
                                onSelectError: controller.selectErrorByIndex,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
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
    _inspectorTreeController.resetSearch();
  }

  void _manualInspectorRefresh() {
    ga.select(
      gac.inspector,
      gac.refresh,
      screenMetricsProvider: () => InspectorScreenMetrics.v2(),
    );
    unawaited(
      blockWhileInProgress(() async {
        await controller.refreshInspector(isManualRefresh: true);
      }),
    );
  }

  Future<void> _maybeShowWelcomeMessage(BuildContext context) async {
    final welcomeAlreadyShown = await storage.getValue(_welcomeShownStorageId);
    if (welcomeAlreadyShown == 'true') return;
    // Mark the welcome message as shown.
    await storage.setValue(_welcomeShownStorageId, 'true');
    if (context.mounted) {
      pushWelcomeToNewInspectorMessage(InspectorScreen.id);
    }
  }
}

class InspectorTreeControls extends StatelessWidget {
  const InspectorTreeControls({
    super.key,
    required this.constraints,
    required this.isSearchVisible,
    required this.onRefreshInspectorPressed,
    required this.onSearchVisibleToggle,
    required this.searchFieldBuilder,
  });

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
                child: Text(
                  'Widget Tree',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                          : const Spacer(),
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
          _controlsContainer(context, Row(children: [_buildSearchControls()])),
      ],
    );
  }

  Container _controlsContainer(BuildContext context, Widget child) {
    return Container(
      height: defaultHeaderHeight,
      decoration: BoxDecoration(
        border: Border(bottom: defaultBorderSide(Theme.of(context))),
      ),
      child: child,
    );
  }

  Widget _buildSearchControls() {
    return Expanded(
      child: SizedBox(
        height: defaultTextFieldHeight,
        child: searchFieldBuilder(),
      ),
    );
  }
}

class ErrorNavigator extends StatelessWidget {
  const ErrorNavigator({
    super.key,
    required this.errors,
    required this.errorIndex,
    required this.onSelectError,
  });

  final LinkedHashMap<String, InspectableWidgetError> errors;

  final int? errorIndex;

  final void Function(int) onSelectError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = errorIndex != null
        ? 'Error ${errorIndex! + 1}/${errors.length}'
        : 'Errors: ${errors.length}';
    return Container(
      color: colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: defaultSpacing,
          vertical: denseSpacing,
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: denseSpacing),
              child: Text(
                label,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
            _ErrorNavigatorButton(
              icon: Icons.keyboard_arrow_up,
              onPressed: _previousError,
            ),
            _ErrorNavigatorButton(
              icon: Icons.keyboard_arrow_down,
              onPressed: _nextError,
            ),
          ],
        ),
      ),
    );
  }

  void _previousError() {
    var newIndex = errorIndex == null ? errors.length - 1 : errorIndex! - 1;
    while (newIndex < 0) {
      newIndex += errors.length;
    }

    onSelectError(newIndex);
  }

  void _nextError() {
    final newIndex = errorIndex == null ? 0 : (errorIndex! + 1) % errors.length;

    onSelectError(newIndex);
  }
}

class _ErrorNavigatorButton extends StatelessWidget {
  const _ErrorNavigatorButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // This is required to force the button size.
      height: defaultButtonHeight,
      width: defaultButtonHeight,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: defaultIconSize,
        icon: Icon(icon),
        color: Theme.of(context).colorScheme.onErrorContainer,
        onPressed: onPressed,
      ),
    );
  }
}
