// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/blocking_action_mixin.dart';
import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/common_widgets.dart';
import '../../shared/connected_app.dart';
import '../../shared/dialogs.dart';
import '../../shared/editable_list.dart';
import '../../shared/error_badge_manager.dart';
import '../../shared/globals.dart';
import '../../shared/screen.dart';
import '../../shared/split.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/icons.dart';
import '../../ui/search.dart';
import 'inspector_controller.dart';
import 'inspector_screen_details_tab.dart';
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
        ProvidedControllerMixin<InspectorController, InspectorScreenBody>,
        SearchFieldMixin<InspectorScreenBody> {
  InspectorTreeController get _summaryTreeController =>
      controller.inspectorTree;

  InspectorTreeController get _detailsTreeController =>
      controller.details!.inspectorTree;

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
    controller.inspectorTree.dispose();
    if (controller.isSummaryTree && controller.details != null) {
      controller.details!.inspectorTree.dispose();
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

    addAutoDisposeListener(searchFieldFocusNode, () {
      // Close the search once focus is lost and following conditions are met:
      //  1. Search string is empty.
      //  2. [searchPreventClose] == false (this is set true when searchTargetType Dropdown is opened).
      if (!searchFieldFocusNode.hasFocus &&
          _summaryTreeController.search.isEmpty &&
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
    addAutoDisposeListener(preferences.inspector.customPubRootDirectories, () {
      _refreshInspector();
    });
    addAutoDisposeListener(serviceManager.isolateManager.mainIsolate, () {
      _refreshInspector();
      preferences.inspector.loadCustomPubRootDirectories();
    });
    preferences.inspector.loadCustomPubRootDirectories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    if (serviceManager.inspectorService == null) {
      // The app must not be a Flutter app.
      return;
    }

    if (!controller.firstInspectorTreeLoadCompleted) {
      ga.timeStart(InspectorScreen.id, analytics_constants.pageReady);
    }

    _summaryTreeController.setSearchTarget(searchTarget);
  }

  @override
  Widget build(BuildContext context) {
    final summaryTree = _buildSummaryTreeColumn();

    final detailsTree = InspectorTree(
      key: detailsTreeKey,
      treeController: _detailsTreeController,
      summaryTreeController: _summaryTreeController,
    );

    final splitAxis = Split.axisFor(context, 0.85);
    final widgetTrees = Split(
      axis: splitAxis,
      initialFractions: const [0.33, 0.67],
      children: [
        summaryTree,
        InspectorDetails(
          detailsTree: detailsTree,
          controller: controller,
        ),
      ],
    );
    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable:
                  serviceManager.serviceExtensionManager.hasServiceExtension(
                extensions.toggleSelectWidgetMode.extension,
              ),
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

  Widget _buildSummaryTreeColumn() {
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
                  controller: _summaryTreeController,
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
                    final inspectableErrors = errors.map(
                      (key, value) =>
                          MapEntry(key, value as InspectableWidgetError),
                    ) as LinkedHashMap<String, InspectableWidgetError>;
                    return Stack(
                      children: [
                        InspectorTree(
                          key: summaryTreeKey,
                          treeController: _summaryTreeController,
                          isSummaryTree: true,
                          widgetErrors: inspectableErrors,
                        ),
                        if (errors.isNotEmpty)
                          ValueListenableBuilder<int?>(
                            valueListenable: controller.selectedErrorIndex,
                            builder: (_, selectedErrorIndex, __) => Positioned(
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
    _summaryTreeController.resetSearch();
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
      const SizedBox(width: defaultSpacing),
      SettingsOutlinedButton(
        tooltip: 'Flutter Inspector Settings',
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => FlutterInspectorSettingsDialog(),
          );
        },
      ),
      // TODO(jacobr): implement TogglePlatformSelector.
      //  TogglePlatformSelector().selector
    ];
  }

  void _refreshInspector() {
    ga.select(analytics_constants.inspector, analytics_constants.refresh);
    blockWhileInProgress(() async {
      // If the user is force refreshing the inspector before the first load has
      // completed, this could indicate a slow load time or that the inspector
      // failed to load the tree once available.
      if (!controller.firstInspectorTreeLoadCompleted) {
        // We do not want to complete this timing operation because the force
        // refresh will skew the results.
        ga.cancelTimingOperation(
          InspectorScreen.id,
          analytics_constants.pageReady,
        );
        ga.select(
          analytics_constants.inspector,
          analytics_constants.refreshEmptyTree,
        );
        controller.firstInspectorTreeLoadCompleted = true;
      }
      await controller.onForceRefresh();
    });
  }
}

class FlutterInspectorSettingsDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogHeight = scaleByFontFactor(400.0);
    return DevToolsDialog(
      title: dialogTitleText(Theme.of(context), 'Flutter Inspector Settings'),
      content: Container(
        width: defaultDialogWidth,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...dialogSubHeader(
              Theme.of(context),
              'General',
            ),
            CheckboxSetting(
              notifier: preferences.inspector.hoverEvalModeEnabled
                  as ValueNotifier<bool?>,
              title: 'Enable hover inspection',
              description:
                  'Hovering over any widget displays its properties and values.',
              gaItem: analytics_constants.inspectorHoverEvalMode,
            ),
            // TODO(CoderDake): add PubRootDirectory section back when
            // finalizing https://github.com/flutter/devtools/issues/3941
            /*
            const SizedBox(height: denseSpacing),
            ...dialogSubHeader(Theme.of(context), 'Package Directories'),
            Text(
              'Widgets in these directories will show up in your summary tree.',
              style: theme.subtleTextStyle,
            ),
            Text(
              '(e.g. /absolute/path/to/myPackage)',
              style: theme.subtleTextStyle,
            ),
            const SizedBox(height: denseSpacing),
            Expanded(
               child: PubRootDirectorySection(),
            ),
            */
          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

class InspectorSummaryTreeControls extends StatelessWidget {
  const InspectorSummaryTreeControls({
    Key? key,
    required this.constraints,
    required this.isSearchVisible,
    required this.onRefreshInspectorPressed,
    required this.onSearchVisibleToggle,
    required this.searchFieldBuilder,
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
    Key? key,
    required this.errors,
    required this.errorIndex,
    required this.onSelectError,
  }) : super(key: key);

  final LinkedHashMap<String, InspectableWidgetError> errors;

  final int? errorIndex;

  final Function(int) onSelectError;

  @override
  Widget build(BuildContext context) {
    final label = errorIndex != null
        ? 'Error ${errorIndex! + 1}/${errors.length}'
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

class PubRootDirectorySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IsolateRef?>(
      valueListenable: serviceManager.isolateManager.mainIsolate,
      builder: (_, __, ___) {
        return Container(
          height: 200.0,
          child: EditableList(
            entries: preferences.inspector.customPubRootDirectories,
            textFieldLabel: 'Enter a new package directory',
            isRefreshing:
                preferences.inspector.isRefreshingCustomPubRootDirectories,
            onEntryAdded: (p0) =>
                preferences.inspector.addPubRootDirectories([p0]),
            onEntryRemoved: (p0) =>
                preferences.inspector.removePubRootDirectories([p0]),
            onRefreshTriggered: () =>
                preferences.inspector.loadCustomPubRootDirectories(),
          ),
        );
      },
    );
  }
}
