// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:collection';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../service/service_extension_widgets.dart';
import '../../service/service_extensions.dart' as extensions;
import '../../shared/analytics/analytics.dart' as ga;
import '../../shared/analytics/constants.dart' as gac;
import '../../shared/common_widgets.dart';
import '../../shared/console/eval/inspector_tree.dart';
import '../../shared/editable_list.dart';
import '../../shared/error_badge_manager.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/blocking_action_mixin.dart';
import '../../shared/primitives/simple_items.dart';
import '../../shared/screen.dart';
import '../../shared/ui/search.dart';
import '../../shared/utils.dart';
import 'inspector_controller.dart';
import 'inspector_screen_details_tab.dart';
import 'inspector_tree_controller.dart';

class InspectorScreen extends Screen {
  InspectorScreen() : super.fromMetaData(ScreenMetaData.inspector);

  static final id = ScreenMetaData.inspector.id;

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
  const InspectorScreenBody({super.key});

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

  @override
  SearchControllerMixin get searchController => _summaryTreeController;

  /// Indicates whether search can be closed. The value is set to true when
  /// search target type dropdown is displayed
  /// TODO(https://github.com/flutter/devtools/issues/3489) use this variable when adding the scope dropdown
  bool searchPreventClose = false;

  SearchTargetType searchTarget = SearchTargetType.widget;

  static const summaryTreeKey = Key('Summary Tree');
  static const detailsTreeKey = Key('Details Tree');
  static const minScreenWidthForTextBeforeScaling = 900.0;
  static const serviceExtensionButtonsIncludeTextWidth = 1200.0;

  @override
  void dispose() {
    _summaryTreeController.dispose();
    if (controller.isSummaryTree && controller.details != null) {
      _detailsTreeController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ga.screen(InspectorScreen.id);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    if (serviceConnection.inspectorService == null) {
      // The app must not be a Flutter app.
      return;
    }

    cancelListeners();
    searchVisible = searchController.search.isNotEmpty;
    addAutoDisposeListener(searchController.searchFieldFocusNode, () {
      // Close the search once focus is lost and following conditions are met:
      //  1. Search string is empty.
      //  2. [searchPreventClose] == false (this is set true when searchTargetType Dropdown is opened).
      if (!searchController.searchFieldFocusNode.hasFocus &&
          searchController.search.isEmpty &&
          !searchPreventClose) {
        setState(() {
          searchVisible = false;
        });
      }

      // Reset [searchPreventClose] state to false after the search field gains focus.
      // Focus is returned automatically once the Dropdown menu is closed.
      if (searchController.searchFieldFocusNode.hasFocus) {
        searchPreventClose = false;
      }
    });
    addAutoDisposeListener(preferences.inspector.pubRootDirectories, () {
      if (serviceConnection.serviceManager.hasConnection &&
          controller.firstInspectorTreeLoadCompleted) {
        _refreshInspector();
      }
    });

    if (!controller.firstInspectorTreeLoadCompleted) {
      ga.timeStart(InspectorScreen.id, gac.pageReady);
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
      screenId: InspectorScreen.id,
    );

    final splitAxis = SplitPane.axisFor(context, 0.85);
    final widgetTrees = SplitPane(
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
              valueListenable: serviceConnection
                  .serviceManager.serviceExtensionManager
                  .hasServiceExtension(
                extensions.toggleSelectWidgetMode.extension,
              ),
              builder: (_, selectModeSupported, __) {
                return ServiceExtensionButtonGroup(
                  extensions: [
                    selectModeSupported
                        ? extensions.toggleSelectWidgetMode
                        : extensions.toggleOnDeviceWidgetInspector,
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
        const SizedBox(height: intermediateSpacing),
        Expanded(
          child: widgetTrees,
        ),
      ],
    );
  }

  Widget _buildSummaryTreeColumn() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RoundedOutlinedBorder(
          child: Column(
            children: [
              InspectorSummaryTreeControls(
                isSearchVisible: searchVisible,
                constraints: constraints,
                onRefreshInspectorPressed: _refreshInspector,
                onSearchVisibleToggle: _onSearchVisibleToggle,
                searchFieldBuilder: () =>
                    StatelessSearchField<InspectorTreeRow>(
                  controller: _summaryTreeController,
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
                          screenId: InspectorScreen.id,
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
    _summaryTreeController.resetSearch();
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
        gaScreen: gac.inspector,
        gaSelection: gac.inspectorSettings,
        tooltip: 'Flutter Inspector Settings',
        onPressed: () {
          unawaited(
            showDialog(
              context: context,
              builder: (context) => const FlutterInspectorSettingsDialog(),
            ),
          );
        },
      ),
      // TODO(jacobr): implement TogglePlatformSelector.
      //  TogglePlatformSelector().selector
    ];
  }

  void _refreshInspector() {
    ga.select(gac.inspector, gac.refresh);
    unawaited(
      blockWhileInProgress(() async {
        // If the user is force refreshing the inspector before the first load has
        // completed, this could indicate a slow load time or that the inspector
        // failed to load the tree once available.
        if (!controller.firstInspectorTreeLoadCompleted) {
          // We do not want to complete this timing operation because the force
          // refresh will skew the results.
          ga.cancelTimingOperation(
            InspectorScreen.id,
            gac.pageReady,
          );
          ga.select(
            gac.inspector,
            gac.refreshEmptyTree,
          );
          controller.firstInspectorTreeLoadCompleted = true;
        }
        await controller.onForceRefresh();
      }),
    );
  }
}

class FlutterInspectorSettingsDialog extends StatelessWidget {
  const FlutterInspectorSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogHeight = scaleByFontFactor(400.0);
    return DevToolsDialog(
      title: const DialogTitleText('Flutter Inspector Settings'),
      content: SizedBox(
        width: defaultDialogWidth,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...dialogSubHeader(
              theme,
              'General',
            ),
            CheckboxSetting(
              notifier: preferences.inspector.hoverEvalModeEnabled
                  as ValueNotifier<bool?>,
              title: 'Enable hover inspection',
              description:
                  'Hovering over any widget displays its properties and values.',
              gaItem: gac.inspectorHoverEvalMode,
            ),
            const SizedBox(height: denseSpacing),
            ...dialogSubHeader(theme, 'Package Directories'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Widgets in these directories will show up in your summary tree.',
                    style: theme.subtleTextStyle,
                  ),
                ),
                MoreInfoLink(
                  url: DocLinks.inspectorPackageDirectories.value,
                  gaScreenName: gac.inspector,
                  gaSelectedItemDescription:
                      gac.InspectorDocs.packageDirectoriesDocs.name,
                ),
              ],
            ),
            Text(
              '(e.g. /absolute/path/to/myPackage/)',
              style: theme.subtleTextStyle,
            ),
            const SizedBox(height: denseSpacing),
            const Expanded(
              child: PubRootDirectorySection(),
            ),
          ],
        ),
      ),
      actions: const [
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
                child: Text(
                  'Widget Tree',
                  style: Theme.of(context).textTheme.titleSmall,
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
          _controlsContainer(
            context,
            Row(children: [_buildSearchControls()]),
          ),
      ],
    );
  }

  Container _controlsContainer(BuildContext context, Widget child) {
    return Container(
      height: defaultHeaderHeight,
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
      child: SizedBox(
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
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                ),
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

class PubRootDirectorySection extends StatelessWidget {
  const PubRootDirectorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IsolateRef?>(
      valueListenable:
          serviceConnection.serviceManager.isolateManager.mainIsolate,
      builder: (_, __, ___) {
        return SizedBox(
          height: 200.0,
          child: EditableList(
            gaScreen: gac.inspector,
            gaRefreshSelection: gac.refreshPubRoots,
            entries: preferences.inspector.pubRootDirectories,
            textFieldLabel: 'Enter a new package directory',
            isRefreshing: preferences.inspector.isRefreshingPubRootDirectories,
            onEntryAdded: (p0) => unawaited(
              preferences.inspector.addPubRootDirectories(
                [p0],
                shouldCache: true,
              ),
            ),
            onEntryRemoved: (p0) =>
                unawaited(preferences.inspector.removePubRootDirectories([p0])),
            onRefreshTriggered: () =>
                unawaited(preferences.inspector.loadPubRootDirectories()),
          ),
        );
      },
    );
  }
}
