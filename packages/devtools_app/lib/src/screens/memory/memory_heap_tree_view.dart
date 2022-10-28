// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/logger/logger.dart' as logger;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/feature_flags.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/split.dart';
import '../../shared/table/table.dart';
import '../../shared/table/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
import 'memory_analyzer.dart';
import 'memory_controller.dart';
import 'memory_filter.dart';
import 'memory_graph_model.dart';
import 'memory_heap_treemap.dart';
import 'memory_instance_tree_view.dart';
import 'memory_snapshot_models.dart';
import 'panes/allocation_profile/allocation_profile_table_view.dart';
import 'panes/allocation_tracing/allocation_profile_tracing_view.dart';
import 'panes/diff/diff_pane.dart';
import 'panes/leaks/leaks_pane.dart';
import 'primitives/memory_utils.dart';

const memorySearchFieldKeyName = 'MemorySearchFieldKey';

@visibleForTesting
final memorySearchFieldKey = GlobalKey(debugLabel: memorySearchFieldKeyName);

enum SnapshotStatus {
  none,
  streaming,
  graphing,
  grouping,
  done,
}

enum WildcardMatch {
  exact,
  startsWith,
  endsWith,
  contains,
}

/// If no wildcard then exact match.
/// *NNN - ends with NNN
/// NNN* - starts with NNN
/// NNN*ZZZ - starts with NNN and ends with ZZZ
const knowClassesToAnalyzeForImages = <WildcardMatch, List<String>>{
  // Anything that contains the phrase:
  WildcardMatch.contains: [
    'Image',
  ],

  // Anything that starts with:
  WildcardMatch.startsWith: [],

  // Anything that exactly matches:
  WildcardMatch.exact: [
    '_Int32List',
    // 32-bit devices e.g., emulators, Pixel 2, raw images as Int32List.
    '_Int64List',
    // 64-bit devices e.g., Pixel 3 XL, raw images as Int64List.
    'FrameInfos',
  ],

  // Anything that ends with:
  WildcardMatch.endsWith: [],
};

/// RegEx expressions to handle the WildcardMatches:
///     Ends with Image:      \[_A-Za-z0-9_]*Image\$
///     Starts with Image:    ^Image
///     Contains Image:       Image
///     Extact Image:         ^Image$
String buildRegExs(Map<WildcardMatch, List<String>> matchingCriteria) {
  final resultRegEx = StringBuffer();
  matchingCriteria.forEach((key, value) {
    if (value.isNotEmpty) {
      final name = value;
      late String regEx;
      // TODO(terry): Need to handle $ for identifier names e.g.,
      //              $FOO is a valid identifier.
      switch (key) {
        case WildcardMatch.exact:
          regEx = '^${name.join("\$|^")}\$';
          break;
        case WildcardMatch.startsWith:
          regEx = '^${name.join("|^")}';
          break;
        case WildcardMatch.endsWith:
          regEx = '^\[_A-Za-z0-9]*${name.join("\|[_A-Za-z0-9]*")}\$';
          break;
        case WildcardMatch.contains:
          regEx = '${name.join("|")}';
          break;
        default:
          assert(false, 'buildRegExs: Unhandled WildcardMatch');
      }
      resultRegEx.write(resultRegEx.isEmpty ? '($regEx' : '|$regEx');
    }
  });

  resultRegEx.write(')');
  return resultRegEx.toString();
}

final String knownClassesRegExs = buildRegExs(knowClassesToAnalyzeForImages);

@visibleForTesting
class MemoryScreenKeys {
  static const searchButton = Key('Snapshot Search');
  static const filterButton = Key('Snapshot Filter');
  static const dartHeapAnalysisTab = Key('Dart Heap Analysis Tab');
  static const leaksTab = Key('Leaks Tab');
  static const dartHeapTableProfileTab = Key('Dart Heap Profile Tab');
  static const dartHeapAllocationTracingTab =
      Key('Dart Heap Allocation Tracing Tab');
  static const diffTab = Key('Diff Tab');
}

class HeapTreeView extends StatefulWidget {
  const HeapTreeView(
    this.controller,
  );

  final MemoryController controller;

  @override
  _HeapTreeViewState createState() => _HeapTreeViewState();
}

class _HeapTreeViewState extends State<HeapTreeView>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, HeapTreeView>,
        SearchFieldMixin<HeapTreeView>,
        TickerProviderStateMixin {
  static const _gaPrefix = 'memoryTab';

  late List<Tab> _tabs;
  late TabController _tabController;
  late Set<Key> _searchableTabs;
  final ValueNotifier<int> _currentTab = ValueNotifier(0);

  Widget? snapshotDisplay;

  /// Used to detect a spike in memory usage.
  MovingAverage heapMovingAverage = MovingAverage(averagePeriod: 100);

  /// Number of seconds between auto snapshots because RSS is exceeded.
  static const maxRSSExceededDurationSecs = 30;

  static const minPercentIncrease = 30;

  /// Timestamp of HeapSample that caused auto snapshot.
  int? spikeSnapshotTime;

  /// Timestamp when RSS exceeded auto snapshot.
  int rssSnapshotTime = 0;

  /// Total memory that caused last snapshot.
  int lastSnapshotMemoryTotal = 0;

  late bool treeMapVisible;

  late AnimationController _animation;

  @override
  void initState() {
    super.initState();

    _animation = _setupBubbleAnimationController();
  }

  void _initTabs() {
    _tabs = [
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapTableProfileTab,
        tabName: 'Profile',
        gaPrefix: _gaPrefix,
      ),
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapAllocationTracingTab,
        tabName: 'Allocation Tracing',
        gaPrefix: _gaPrefix,
      ),
      DevToolsTab.create(
        key: MemoryScreenKeys.dartHeapAnalysisTab,
        gaPrefix: _gaPrefix,
        tabName: 'Analysis',
      ),
      if (FeatureFlags.memoryDiffing)
        DevToolsTab.create(
          key: MemoryScreenKeys.diffTab,
          gaPrefix: _gaPrefix,
          tabName: 'Diff',
        ),
      if (widget.controller.shouldShowLeaksTab.value)
        DevToolsTab.create(
          key: MemoryScreenKeys.leaksTab,
          gaPrefix: _gaPrefix,
          tabName: 'Leaks',
        ),
    ];

    _searchableTabs = {
      MemoryScreenKeys.dartHeapAnalysisTab,
    };
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() => _currentTab.value = _tabController.index;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    _initTabs();

    addAutoDisposeListener(controller.shouldShowLeaksTab, () {
      setState(() {
        _initTabs();
      });
    });

    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.selectionSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.leafSelectedNotifier, () {
      setState(() {
        controller.computeRoot();
      });
    });

    addAutoDisposeListener(controller.leafAnalysisSelectedNotifier, () {
      setState(() {
        controller.computeAnalysisInstanceRoot();
      });
    });

    addAutoDisposeListener(controller.searchNotifier, () {
      controller.closeAutoCompleteOverlay();
      controller..setCurrentHoveredIndexValue(0);
    });

    addAutoDisposeListener(controller.searchAutoCompleteNotifier, () {
      ga.select(
        analytics_constants.memory,
        analytics_constants.snapshotFilterDialog,
      );
      controller.handleAutoCompleteOverlay(
        context: context,
        searchFieldKey: memorySearchFieldKey,
        onTap: selectTheMatch,
      );
    });

    addAutoDisposeListener(controller.memoryTimeline.sampleAddedNotifier, () {
      autoSnapshot();
    });

    treeMapVisible = controller.treeMapVisible.value;
    addAutoDisposeListener(controller.treeMapVisible, () {
      setState(() {
        treeMapVisible = controller.treeMapVisible.value;
      });
    });
  }

  @override
  void dispose() {
    _animation.dispose();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();

    super.dispose();
  }

  /// Enable to output debugging information for auto-snapshot.
  /// WARNING: Do not checkin with this flag set to true.
  final debugSnapshots = false;

  /// Detect spike in memory usage if so do an automatic snapshot.
  void autoSnapshot() {
    if (!preferences.memory.autoSnapshotEnabled.value) return;
    final heapSample = controller.memoryTimeline.sampleAddedNotifier.value!;
    final heapSum = heapSample.external + heapSample.used;
    heapMovingAverage.add(heapSum);

    final dateTimeFormat = DateFormat('HH:mm:ss.SSS');
    final startDateTime = dateTimeFormat
        .format(DateTime.fromMillisecondsSinceEpoch(heapSample.timestamp));

    if (debugSnapshots) {
      debugLogger(
        'AutoSnapshot $startDateTime heapSum=$heapSum, '
        'first=${heapMovingAverage.dataSet.first}, '
        'mean=${heapMovingAverage.mean}',
      );
    }

    bool takeSnapshot = false;
    final sampleTime = Duration(milliseconds: heapSample.timestamp);

    final rssExceeded = heapSum > heapSample.rss;
    if (rssExceeded) {
      final increase = heapSum - lastSnapshotMemoryTotal;
      final rssPercentIncrease = lastSnapshotMemoryTotal > 0
          ? increase / lastSnapshotMemoryTotal * 100
          : 0;
      final rssTime = Duration(milliseconds: rssSnapshotTime);
      // Number of seconds since last snapshot happens because of RSS exceeded.
      // Reduce rapid fire snapshots.
      final rssSnapshotPeriod = (sampleTime - rssTime).inSeconds;
      if (rssSnapshotPeriod > maxRSSExceededDurationSecs) {
        // minPercentIncrease larger than previous auto RSS snapshot then
        // take another snapshot.
        if (rssPercentIncrease > minPercentIncrease) {
          rssSnapshotTime = heapSample.timestamp;
          lastSnapshotMemoryTotal = heapSum;

          takeSnapshot = true;
          debugLogger(
            'AutoSnapshot - RSS exceeded '
            '($rssPercentIncrease% increase) @ $startDateTime.',
          );
        }
      }
    }

    if (!takeSnapshot && heapMovingAverage.hasSpike()) {
      final snapshotTime =
          Duration(milliseconds: spikeSnapshotTime ?? heapSample.timestamp);
      spikeSnapshotTime = heapSample.timestamp;
      takeSnapshot = true;
      logger.log(
        'AutoSnapshot - memory spike @ $startDateTime} '
        'last snapshot ${(sampleTime - snapshotTime).inSeconds} seconds ago.',
      );
      debugLogger(
        '               '
        'heap @ last snapshot = $lastSnapshotMemoryTotal, '
        'heap total=$heapSum, RSS=${heapSample.rss}',
      );
    }

    if (takeSnapshot) {
      assert(!heapMovingAverage.isDipping());
      // Reset moving average for next spike.
      heapMovingAverage.clear();
      // TODO(terry): Should get the real sum of the snapshot not the current memory.
      //              Snapshot can take a bit and could be a lag.
      lastSnapshotMemoryTotal = heapSum;
      _takeHeapSnapshot(userGenerated: false);
    } else if (heapMovingAverage.isDipping()) {
      // Reset the two things we're tracking spikes and RSS exceeded.
      heapMovingAverage.clear();
      lastSnapshotMemoryTotal = heapSum;
    }
  }

  SnapshotStatus snapshotState = SnapshotStatus.none;

  bool get _isSnapshotRunning =>
      snapshotState != SnapshotStatus.done &&
      snapshotState != SnapshotStatus.none;

  bool get _isSnapshotStreaming => snapshotState == SnapshotStatus.streaming;

  bool get _isSnapshotGraphing => snapshotState == SnapshotStatus.graphing;

  bool get _isSnapshotGrouping => snapshotState == SnapshotStatus.grouping;

  bool get _isSnapshotComplete => snapshotState == SnapshotStatus.done;

  @override
  Widget build(BuildContext context) {
    final themeData = Theme.of(context);

    if (_isSnapshotRunning) {
      snapshotDisplay = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50.0),
          snapshotDisplay = const CircularProgressIndicator(),
          const SizedBox(height: denseSpacing),
          Text(
            _isSnapshotStreaming
                ? 'Processing...'
                : _isSnapshotGraphing
                    ? 'Graphing...'
                    : _isSnapshotGrouping
                        ? 'Grouping...'
                        : _isSnapshotComplete
                            ? 'Done'
                            : '...',
          ),
        ],
      );
    } else if (controller.snapshotByLibraryData != null) {
      snapshotDisplay =
          treeMapVisible ? const MemoryHeapTreemap() : MemoryHeapTable();
    } else {
      snapshotDisplay = null;
    }

    return Column(
      children: [
        const SizedBox(height: defaultSpacing),
        ValueListenableBuilder<int>(
          valueListenable: _currentTab,
          builder: (context, index, _) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                labelColor: themeData.textTheme.bodyLarge!.color,
                isScrollable: true,
                controller: _tabController,
                tabs: _tabs,
              ),
              if (_searchableTabs.contains(_tabs[index].key))
                _buildSearchFilterControls(),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: TabBarView(
            physics: defaultTabBarViewPhysics,
            controller: _tabController,
            children: [
              // Profile Tab
              KeepAliveWrapper(
                child: AllocationProfileTableView(
                  controller: controller.allocationProfileController,
                ),
              ),
              const KeepAliveWrapper(
                child: AllocationProfileTracingView(),
              ),
              // Analysis Tab
              KeepAliveWrapper(
                child: Column(
                  children: [
                    _buildSnapshotControls(themeData.textTheme),
                    const SizedBox(height: denseRowSpacing),
                    Expanded(
                      child: buildSnapshotTables(snapshotDisplay),
                    ),
                  ],
                ),
              ),
              // Diff tab.
              if (FeatureFlags.memoryDiffing)
                KeepAliveWrapper(
                  child: DiffPane(
                    diffController: controller.diffPaneController,
                  ),
                ),
              // Leaks tab.
              if (controller.shouldShowLeaksTab.value)
                const KeepAliveWrapper(child: LeaksPane()),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildSnapshotTables(Widget? snapshotDisplay) {
    if (snapshotDisplay == null) {
      // Display help text about how to collect data.
      return OutlineDecoration(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Click the take heap snapshot button '),
              Icon(Icons.camera),
              Text(' to collect a graph of memory objects.'),
            ],
          ),
        ),
      );
    }

    final rightSideTable = controller.isLeafSelected
        ? InstanceTreeView()
        : controller.isAnalysisLeafSelected
            ? Expanded(child: AnalysisInstanceViewTable())
            : helpScreen();

    return treeMapVisible
        ? snapshotDisplay
        : Split(
            initialFractions: const [0.5, 0.5],
            minSizes: const [300, 300],
            axis: Axis.horizontal,
            children: [
              // TODO(terry): Need better focus handling between 2 tables & up/down
              //              arrows in the right-side field instance view table.
              snapshotDisplay,
              OutlineDecoration(child: rightSideTable),
            ],
          );
  }

  Widget tableExample(IconData? iconData, String entry) {
    final themeData = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        iconData == null
            ? Text(' ', style: themeData.fixedFontStyle)
            : Icon(iconData),
        Text(entry, style: themeData.fixedFontStyle),
      ],
    );
  }

  Widget helpScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Click a leaf node instance of a class to\n'
          'inspect the fields of that instance e.g.,',
        ),
        const SizedBox(height: defaultSpacing),
        tableExample(Icons.expand_more, 'dart:collection'),
        tableExample(Icons.expand_more, 'SplayTreeMap'),
        const SizedBox(height: denseRowSpacing),
        tableExample(null, 'Instance 0'),
      ],
    );
  }

  @visibleForTesting
  static const groupByMenuButtonKey = Key('Group By Menu Button');
  @visibleForTesting
  static const groupByMenuItem = Key('Group By Menu Item');
  @visibleForTesting
  static const groupByKey = Key('Group By');

  Widget _groupByDropdown(TextTheme textTheme) {
    final _groupByTypes = [
      MemoryController.groupByLibrary,
      MemoryController.groupByClass,
      MemoryController.groupByInstance,
    ].map<DropdownMenuItem<String>>(
      (
        String value,
      ) {
        return DropdownMenuItem<String>(
          key: groupByMenuItem,
          value: value,
          child: Text(
            'Group by $value',
            key: groupByKey,
          ),
        );
      },
    ).toList();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        key: groupByMenuButtonKey,
        style: textTheme.bodyMedium,
        value: controller.groupingBy.value,
        onChanged: (String? newValue) {
          setState(
            () {
              ga.select(
                analytics_constants.memory,
                '${analytics_constants.groupByPrefix}$newValue',
              );
              controller.selectedLeaf = null;
              controller.groupingBy.value = newValue!;
              if (controller.snapshots.isNotEmpty) {
                doGroupBy();
              }
            },
          );
        },
        items: _groupByTypes,
      ),
    );
  }

  Widget _buildSnapshotControls(TextTheme textTheme) {
    return SizedBox(
      height: defaultButtonHeight,
      child: Row(
        children: [
          IconLabelButton(
            tooltip: 'Take a memory profile snapshot',
            icon: Icons.camera,
            label: 'Take Heap Snapshot',
            onPressed: _isSnapshotRunning ? null : _takeHeapSnapshot,
          ),
          const SizedBox(width: defaultSpacing),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Treemap'),
              Switch(
                value: treeMapVisible,
                onChanged: controller.snapshotByLibraryData != null
                    ? (value) {
                        ga.select(
                          analytics_constants.memory,
                          '${analytics_constants.treemapToggle}-'
                          '${value ? 'show' : 'hide'}',
                        );
                        controller.toggleTreeMapVisible(value);
                      }
                    : null,
              ),
            ],
          ),
          if (!treeMapVisible) ...[
            const SizedBox(width: defaultSpacing),
            _groupByDropdown(textTheme),
            const SizedBox(width: defaultSpacing),
            // TODO(terry): Mechanism to handle expand/collapse on both tables
            // objects/fields. Maybe notion in table?
            ExpandAllButton(
              onPressed: () {
                ga.select(
                  analytics_constants.memory,
                  analytics_constants.expandAll,
                );
                if (snapshotDisplay is MemoryHeapTable) {
                  controller.groupByTreeTable.dataRoots.every((element) {
                    element.expandCascading();
                    return true;
                  });
                }
                // All nodes expanded - signal tree state  changed.
                controller.treeChanged();
              },
            ),
            const SizedBox(width: denseSpacing),
            CollapseAllButton(
              onPressed: () {
                ga.select(
                  analytics_constants.memory,
                  analytics_constants.collapseAll,
                );
                if (snapshotDisplay is MemoryHeapTable) {
                  controller.groupByTreeTable.dataRoots.every((element) {
                    element.collapseCascading();
                    return true;
                  });
                  if (controller.instanceFieldsTreeTable != null) {
                    // We're collapsing close the fields table.
                    controller.selectedLeaf = null;
                  }
                  // All nodes collapsed - signal tree state changed.
                  controller.treeChanged();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  AnimationController _setupBubbleAnimationController() {
    // Setup animation controller to handle the update bubble.
    const animationDuration = Duration(milliseconds: 500);
    final bubbleAnimation = AnimationController(
      duration: animationDuration,
      reverseDuration: animationDuration,
      upperBound: 15.0,
      vsync: this,
    );

    bubbleAnimation.addStatusListener(_animationStatusListener);

    return bubbleAnimation;
  }

  void _animationStatusListener(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      // Reverse from larger bubble back to normal bubble radius.
      _animation.reverse();
    }
  }

  Timer? removeUpdateBubble;

  Widget textWidgetWithUpdateCircle(
    String text, {
    TextStyle? style,
    double? size,
  }) {
    final textWidth = textWidgetWidth(text, style: style);

    return Stack(
      children: [
        Positioned(
          child: Container(
            width: textWidth + 10,
            child: Text(text, style: style),
          ),
        ),
        Positioned(
          right: 0,
          child: Container(
            alignment: Alignment.topRight,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[400],
            ),
            child: const Icon(Icons.fiber_manual_record, size: 0),
          ),
        ),
      ],
    );
  }

  static const maxWidth = 800.0;

  double textWidgetWidth(String message, {TextStyle? style}) {
    // Longest message must fit in this width.
    const constraints = BoxConstraints(
      maxWidth: maxWidth,
    );

    // TODO(terry): Is there a better (less heavyweight) way of computing text
    //              width than using the widget pipeline?
    final richTextWidget = Text.rich(TextSpan(text: message), style: style)
        .build(context) as RichText;
    final renderObject = richTextWidget.createRenderObject(context);
    renderObject.layout(constraints);
    final boxes = renderObject.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: TextSpan(text: message).toPlainText().length,
      ),
    );

    final textWidth = boxes.last.right;

    if (textWidth > maxWidth) {
      // TODO(terry): If message > 800 pixels in width (not possible
      //              today) but could be more robust.
      logger.log(
        'Computed text width > $maxWidth ($textWidth)\nmessage=$message.',
        logger.LogLevel.warning,
      );
    }

    return textWidth;
  }

  /// Match, found,  select it and process via ValueNotifiers.
  void selectTheMatch(String foundName) {
    ga.select(
      analytics_constants.memory,
      analytics_constants.autoCompleteSearchSelect,
    );

    setState(() {
      if (snapshotDisplay is MemoryHeapTable) {
        controller.groupByTreeTable.dataRoots.every((element) {
          element.collapseCascading();
          return true;
        });
      }
    });

    selectFromSearchField(controller, foundName);
    clearSearchField(controller);
  }

  Widget _buildSearchWidget(GlobalKey<State<StatefulWidget>> key) => Container(
        width: wideSearchTextWidth,
        height: defaultTextFieldHeight,
        child: buildAutoCompleteSearchField(
          controller: controller,
          searchFieldKey: key,
          searchFieldEnabled: !treeMapVisible,
          shouldRequestFocus: !treeMapVisible,
          onSelection: selectTheMatch,
          supportClearField: true,
        ),
      );

  Widget _buildSearchFilterControls() => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _buildSearchWidget(memorySearchFieldKey),
          const SizedBox(width: denseSpacing),
          FilterButton(
            key: MemoryScreenKeys.filterButton,
            onPressed: _filter,
            // TODO(kenz): implement isFilterActive
            isFilterActive: false,
          ),
        ],
      );

  // TODO: Much of the logic for _takeHeapSnapshot() might want to move into the
  // controller.
  void _takeHeapSnapshot({bool userGenerated = true}) async {
    ga.select(
      analytics_constants.memory,
      analytics_constants.takeSnapshot,
    );

    // VmService not available (disconnected/crashed).
    if (serviceManager.service == null) return;

    // Another snapshot in progress, don't stall the world. An auto-snapshot
    // is probably in progress.
    if (snapshotState != SnapshotStatus.none &&
        snapshotState != SnapshotStatus.done) {
      debugLogger('Snapshot in progress - ignoring this request.');
      return;
    }

    controller.memoryTimeline.addSnapshotEvent(auto: !userGenerated);

    setState(() {
      snapshotState = SnapshotStatus.streaming;
    });

    final snapshotTimestamp = DateTime.now();

    final graph = await snapshotMemory();

    // No snapshot collected, disconnected/crash application.
    if (graph == null) {
      setState(() {
        snapshotState = SnapshotStatus.done;
      });
      controller.selectedSnapshotTimestamp = DateTime.now();
      return;
    }

    final snapshotCollectionTime = DateTime.now();

    setState(() {
      snapshotState = SnapshotStatus.graphing;
    });

    // To debug particular classes add their names to the last
    // parameter classNamesToMonitor e.g., ['AppStateModel', 'Terry', 'TerryEntry']
    controller.heapGraph = convertHeapGraph(
      controller.filterConfig,
      graph,
      [],
    );
    final snapshotGraphTime = DateTime.now();

    setState(() {
      snapshotState = SnapshotStatus.grouping;
    });

    await doGroupBy();

    final root = controller.computeAllLibraries(graph: graph)!;

    final snapshot = controller.storeSnapshot(
      snapshotTimestamp,
      graph,
      root,
      autoSnapshot: !userGenerated,
    );

    final snapshotDoneTime = DateTime.now();

    controller.selectedSnapshotTimestamp = snapshotTimestamp;

    debugLogger(
      'Total Snapshot completed in'
      ' ${snapshotDoneTime.difference(snapshotTimestamp).inMilliseconds / 1000} seconds',
    );
    debugLogger(
      '  Snapshot collected in'
      ' ${snapshotCollectionTime.difference(snapshotTimestamp).inMilliseconds / 1000} seconds',
    );
    debugLogger(
      '  Snapshot graph built in'
      ' ${snapshotGraphTime.difference(snapshotCollectionTime).inMilliseconds / 1000} seconds',
    );
    debugLogger(
      '  Snapshot grouping/libraries computed in'
      ' ${snapshotDoneTime.difference(snapshotGraphTime).inMilliseconds / 1000} seconds',
    );

    setState(() {
      snapshotState = SnapshotStatus.done;
    });

    controller.buildTreeFromAllData();
    _analyze(snapshot: snapshot);
  }

  Future<void> doGroupBy() async {
    controller.heapGraph!
      ..computeInstancesForClasses()
      ..computeRawGroups()
      ..computeFilteredGroups();
  }

  void _filter() {
    ga.select(
      analytics_constants.memory,
      analytics_constants.snapshotFilterDialog,
    );
    // TODO(terry): Remove barrierDismissble and make clicking outside
    //              dialog same as cancel.
    // Dialog isn't dismissed by clicking outside the dialog (modal).
    // Pressing either the Apply or Cancel button will dismiss.
    showDialog(
      context: context,
      builder: (BuildContext context) => SnapshotFilterDialog(controller),
      barrierDismissible: false,
    );
  }

  void _debugCheckAnalyses(DateTime currentSnapDateTime) {
    // Debug only check.
    assert(
      () {
        // Analysis already completed we're done.
        final foundMatch = controller.completedAnalyses.firstWhereOrNull(
          (element) => element.dateTime.compareTo(currentSnapDateTime) == 0,
        );
        if (foundMatch != null) {
          logger.log(
            'Analysis '
            '${MemoryController.formattedTimestamp(currentSnapDateTime)} '
            'already computed.',
            logger.LogLevel.warning,
          );
        }
        return true;
      }(),
    );
  }

  void _analyze({Snapshot? snapshot}) {
    final AnalysesReference analysesNode = controller.findAnalysesNode()!;

    snapshot ??= controller.computeSnapshotToAnalyze!;
    final DateTime currentSnapDateTime = snapshot.collectedTimestamp;

    _debugCheckAnalyses(currentSnapDateTime);

    // If there's an empty place holder than remove it. First analysis will
    // exist shortly.
    if (analysesNode.children.length == 1 &&
        analysesNode.children.first.name!.isEmpty) {
      analysesNode.children.clear();
    }

    // Create analysis node to hold analysis results.
    final analyzeSnapshot = AnalysisSnapshotReference(currentSnapDateTime);
    analysesNode.addChild(analyzeSnapshot);

    // Analyze this snapshot.
    final collectedData = collect(controller, snapshot);

    // Analyze the collected data.

    // 1. Analysis of memory image usage.
    imageAnalysis(controller, analyzeSnapshot, collectedData);

    // Add to our list of completed analyses.
    controller.completedAnalyses.add(analyzeSnapshot);

    // Expand the 'Analysis' node.
    if (!analysesNode.isExpanded) {
      analysesNode.expand();
    }

    // Select the snapshot just analyzed.
    controller.selectionSnapshotNotifier.value = Selection(
      node: analyzeSnapshot,
      nodeIndex: analyzeSnapshot.index,
      scrollIntoView: true,
    );
  }
}

/// Snapshot TreeTable
class MemoryHeapTable extends StatefulWidget {
  @override
  MemoryHeapTableState createState() => MemoryHeapTableState();
}

/// A table of the Memory graph class top-down call tree.
class MemoryHeapTableState extends State<MemoryHeapTable>
    with
        AutoDisposeMixin,
        ProvidedControllerMixin<MemoryController, MemoryHeapTable> {
  final TreeColumnData<Reference> _treeColumn = _LibraryRefColumn();

  final List<ColumnData<Reference>> _columns = [];

  @override
  void initState() {
    super.initState();

    // Setup the table columns.
    _columns.addAll([
      _treeColumn,
      _ClassOrInstanceCountColumn(),
      _ShallowSizeColumn(),
      // TODO(terry): Don't display until dominator is implemented
      //              Issue https://github.com/flutter/devtools/issues/2688
      // _RetainedSizeColumn(),
    ]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initController()) return;

    cancelListeners();

    // Update the tree when the tree state changes e.g., expand, collapse, etc.
    addAutoDisposeListener(controller.treeChangedNotifier, () {
      if (controller.isTreeChanged) {
        setState(() {});
      }
    });

    // Update the tree when the memorySource changes.
    addAutoDisposeListener(controller.selectedSnapshotNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.filterNotifier, () {
      setState(() {
        controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(controller.searchAutoCompleteNotifier);

    addAutoDisposeListener(controller.selectTheSearchNotifier, _handleSearch);

    addAutoDisposeListener(controller.searchNotifier, _handleSearch);
  }

  void _handleSearch() {
    final searchingValue = controller.search;
    if (searchingValue.isNotEmpty) {
      if (controller.selectTheSearch) {
        // Found an exact match.
        selectItemInTree(searchingValue);
        controller.selectTheSearch = false;
        controller.resetSearch();
        return;
      }

      // No exact match, return the list of possible matches.
      controller.clearSearchAutoComplete();

      final matches = _snapshotMatches(searchingValue);

      // Remove duplicates and sort the matches.
      final normalizedMatches = matches.toSet().toList()..sort();
      // Use the top 10 matches:
      controller.searchAutoComplete.value = normalizedMatches
          .sublist(
            0,
            min(
              topMatchesLimit,
              normalizedMatches.length,
            ),
          )
          .map((match) => AutoCompleteMatch(match))
          .toList();
    }
  }

  List<String> _snapshotMatches(String searchingValue) {
    final matches = <String>[];

    final externalMatches = <String>[];
    final filteredMatches = <String>[];

    switch (controller.groupingBy.value) {
      case MemoryController.groupByLibrary:
        final searchRoot = controller.activeSnapshot;
        for (final reference in searchRoot.children) {
          if (reference.isLibrary) {
            matches.addAll(
              matchesInLibrary(reference as LibraryReference, searchingValue),
            );
          } else if (reference.isExternals) {
            final refs = reference as ExternalReferences;
            for (final ext in refs.children.cast<ExternalReference>()) {
              final match = matchSearch(ext, searchingValue);
              if (match != null) {
                externalMatches.add(match);
              }
            }
          } else if (reference.isFiltered) {
            // Matches in the filtered nodes.
            final filteredReference = reference as FilteredReference;
            for (final library in filteredReference.children) {
              filteredMatches.addAll(
                matchesInLibrary(
                  library as LibraryReference,
                  searchingValue,
                ),
              );
            }
          }
        }
        break;
      case MemoryController.groupByClass:
        matches.addAll(
          matchClasses(
            controller.groupByTreeTable.dataRoots,
            searchingValue,
          ),
        );
        break;
      case MemoryController.groupByInstance:
        // TODO(terry): TBD
        break;
    }

    // Ordered in importance (matches, external, filtered).
    matches.addAll(externalMatches);
    matches.addAll(filteredMatches);
    return matches;
  }

  List<String> _maybeAddMatch(Reference reference, String search) {
    final matches = <String>[];

    final match = matchSearch(reference, search);
    if (match != null) {
      matches.add(match);
    }

    return matches;
  }

  List<String> matchesInLibrary(
    LibraryReference libraryReference,
    String searchingValue,
  ) {
    final matches = _maybeAddMatch(libraryReference, searchingValue);

    final List<Reference> classes = libraryReference.children;
    matches.addAll(matchClasses(classes, searchingValue));

    return matches;
  }

  List<String> matchClasses(
    List<Reference> classReferences,
    String searchingValue,
  ) {
    final matches = <String>[];

    // Check the class names in the library
    for (final ClassReference classReference
        in classReferences.cast<ClassReference>()) {
      matches.addAll(_maybeAddMatch(classReference, searchingValue));
    }

    // Remove duplicates
    return matches;
  }

  /// Return null if no match, otherwise string.
  String? matchSearch(Reference ref, String matchString) {
    final knownName = ref.name!.toLowerCase();
    if (knownName.contains(matchString.toLowerCase())) {
      return ref.name;
    }
    return null;
  }

  /// This finds and selects an exact match in the tree.
  /// Returns `true` if [searchingValue] is found in the tree.
  bool selectItemInTree(String searchingValue) {
    // Search the snapshots.
    switch (controller.groupingBy.value) {
      case MemoryController.groupByLibrary:
        final searchRoot = controller.activeSnapshot;
        if (controller.selectionSnapshotNotifier.value.node == null) {
          // No selected node, then select the snapshot we're searching.
          controller.selectionSnapshotNotifier.value = Selection(
            node: searchRoot,
            nodeIndex: searchRoot.index,
            scrollIntoView: true,
          );
        }
        for (final reference in searchRoot.children) {
          if (reference.isLibrary) {
            final foundIt = _selectItemInTree(reference, searchingValue);
            if (foundIt) {
              return true;
            }
          } else if (reference.isFiltered) {
            // Matches in the filtered nodes.
            final filteredReference = reference as FilteredReference;
            for (final library in filteredReference.children) {
              final foundIt = _selectItemInTree(library, searchingValue);
              if (foundIt) {
                return true;
              }
            }
          } else if (reference.isExternals) {
            final refs = reference as ExternalReferences;
            for (final external in refs.children.cast<ExternalReference>()) {
              final foundIt = _selectItemInTree(external, searchingValue);
              if (foundIt) {
                return true;
              }
            }
          }
        }
        break;
      case MemoryController.groupByClass:
        for (final reference in controller.groupByTreeTable.dataRoots) {
          if (reference.isClass) {
            return _selecteClassInTree(reference, searchingValue);
          }
        }
        break;
      case MemoryController.groupByInstance:
        // TODO(terry): TBD
        break;
    }

    return false;
  }

  bool _selectInTree(Reference reference, search) {
    if (reference.name == search) {
      controller.selectionSnapshotNotifier.value = Selection(
        node: reference,
        nodeIndex: reference.index,
        scrollIntoView: true,
      );
      controller.clearSearchAutoComplete();
      return true;
    }
    return false;
  }

  bool _selectItemInTree(Reference reference, String searchingValue) {
    // TODO(terry): Only finds first one.
    if (_selectInTree(reference, searchingValue)) return true;

    // Check the class names in the library
    return _selecteClassInTree(reference, searchingValue);
  }

  bool _selecteClassInTree(Reference reference, String searchingValue) {
    // Check the class names in the library
    for (final Reference classReference in reference.children) {
      // TODO(terry): Only finds first one.
      if (_selectInTree(classReference, searchingValue)) return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final root = controller.buildTreeFromAllData();
    Widget result;
    if (root != null && root.children.isNotEmpty) {
      // Snapshots and analyses exists display the trees.
      controller.groupByTreeTable = TreeTable<Reference>(
        keyFactory: (libRef) => PageStorageKey<String?>(libRef.name),
        dataRoots: root.children,
        dataKey: 'memory-snapshot-tree',
        columns: _columns,
        treeColumn: _treeColumn,
        defaultSortColumn: _columns[0],
        defaultSortDirection: SortDirection.ascending,
        selectionNotifier: controller.selectionSnapshotNotifier,
      );

      result = controller.groupByTreeTable;
    } else {
      // Nothing collected yet (snapshots/analyses) - return an empty area.
      result = const SizedBox();
    }
    return OutlineDecoration(child: result);
  }
}

class _LibraryRefColumn extends TreeColumnData<Reference> {
  _LibraryRefColumn() : super('Library or Class');

  @override
  String getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    if (dataObject.isLibrary) {
      final value = (dataObject as LibraryReference).name ?? '';
      final splitValues = value.split('/');

      return splitValues.length > 1
          ? '${splitValues[0]}/${splitValues[1]}'
          : splitValues[0];
    }

    return dataObject.name ?? '';
  }

  @override
  String getDisplayValue(Reference dataObject) => getValue(dataObject);

  @override
  bool get supportsSorting => true;

  @override
  String getTooltip(Reference dataObject) {
    return dataObject.name ?? '';
  }
}

class _ClassOrInstanceCountColumn extends ColumnData<Reference> {
  _ClassOrInstanceCountColumn()
      : super(
          'Count',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(75.0),
        );

  @override
  int getValue(Reference dataObject) {
    assert(!dataObject.isEmptyReference);

    // Although the method returns dynamic this implementatation only
    // returns int.

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) return 0;

    if (dataObject.isExternal) {
      return dataObject.children.length;
    }

    if (dataObject.isAnalysis && dataObject is AnalysisReference) {
      final AnalysisReference analysisReference = dataObject;
      return analysisReference.countNote ?? 0;
    }

    if (dataObject.isSnapshot && dataObject is SnapshotReference) {
      int count = 0;
      final SnapshotReference snapshotRef = dataObject;
      for (final child in snapshotRef.children) {
        count += _computeCount(child);
      }
      return count;
    }

    return _computeCount(dataObject);
  }

  /// Return a count based on the Reference type e.g., library, filtered,
  /// class, externals, etc.  Only compute once, store in the Reference.
  int _computeCount(Reference ref) {
    // Only compute the children counts once then store in the Reference.
    if (ref.hasCount) return ref.count!;

    int count = 0;

    if (ref.isClass) {
      final classRef = ref as ClassReference;
      count = _computeClassInstances(classRef.actualClass!)!;
    } else if (ref.isLibrary) {
      // Return number of classes.
      final LibraryReference libraryReference = ref as LibraryReference;
      for (final heapClass in libraryReference.actualClasses!) {
        count += _computeClassInstances(heapClass)!;
      }
    } else if (ref.isFiltered) {
      final FilteredReference filteredRef = ref as FilteredReference;
      for (final LibraryReference child
          in filteredRef.children.cast<LibraryReference>()) {
        for (final heapClass in child.actualClasses!) {
          count += _computeClassInstances(heapClass)!;
        }
      }
    } else if (ref.isExternals) {
      for (ExternalReference externalRef
          in ref.children.cast<ExternalReference>()) {
        count += externalRef.children.length;
      }
    } else if (ref.isExternal) {
      final ExternalReference externalRef = ref as ExternalReference;
      count = externalRef.children.length;
    }

    // Only compute once.
    ref.count = count;

    return count;
  }

  int? _computeClassInstances(HeapGraphClassLive liveClass) =>
      liveClass.instancesCount != null ? liveClass.instancesCount : null;

  /// Internal helper for all count values.
  String _displayCount(int? count) => count == null ? '--' : '$count';

  @override
  String getDisplayValue(Reference dataObject) =>
      _displayCount(getValue(dataObject));

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }
}

class _ShallowSizeColumn extends ColumnData<Reference> {
  _ShallowSizeColumn()
      : super(
          'Shallow',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  int sizeAllVisibleLibraries(List<Reference> references) {
    var sum = 0;
    for (final ref in references) {
      if (ref.isLibrary) {
        final libraryReference = ref as LibraryReference;
        for (final actualClass in libraryReference.actualClasses!) {
          sum += actualClass.instancesTotalShallowSizes;
        }
      }
    }
    return sum;
  }

  @override
  dynamic getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) {
      final snapshot = dataObject.controller!.getSnapshot(dataObject)!;
      final snapshotGraph = snapshot.snapshotGraph;
      return snapshotGraph.shallowSize + snapshotGraph.externalSize;
    }

    if (dataObject.isAnalysis && dataObject is AnalysisReference) {
      final AnalysisReference analysisReference = dataObject;
      final size = analysisReference.sizeNote;
      return size ?? '';
    } else if (dataObject.isSnapshot && dataObject is SnapshotReference) {
      var sum = 0;
      final SnapshotReference snapshotRef = dataObject;
      for (final childRef in snapshotRef.children) {
        sum += _sumShallowSize(childRef) ?? 0;
      }
      return sum;
    } else {
      final sum = _sumShallowSize(dataObject);
      return sum ?? '';
    }
  }

  int? _sumShallowSize(Reference ref) {
    if (ref.isLibrary) {
      // Return number of classes.
      final libraryReference = ref as LibraryReference;
      var sum = 0;
      for (final actualClass in libraryReference.actualClasses!) {
        sum += actualClass.instancesTotalShallowSizes;
      }
      return sum;
    } else if (ref.isClass) {
      final classReference = ref as ClassReference;
      return classReference.actualClass!.instancesTotalShallowSizes;
    } else if (ref.isObject) {
      // Return number of instances.
      final objectReference = ref as ObjectReference;

      var size = objectReference.instance.origin.shallowSize;

      // If it's an external object then return the externalSize too.
      if (ref is ExternalObjectReference) {
        final ExternalObjectReference externalRef = ref;
        size += externalRef.externalSize;
      }

      return size;
    } else if (ref.isFiltered) {
      final snapshot = ref.controller!.getSnapshot(ref)!;
      final sum = sizeAllVisibleLibraries(snapshot.libraryRoot?.children ?? []);
      final snapshotGraph = snapshot.snapshotGraph;
      return snapshotGraph.shallowSize - sum;
    } else if (ref.isExternals) {
      final snapshot = ref.controller!.getSnapshot(ref)!;
      return snapshot.snapshotGraph.externalSize;
    } else if (ref.isExternal) {
      return (ref as ExternalReference).sumExternalSizes;
    }

    return null;
  }

  @override
  String getDisplayValue(Reference dataObject) {
    final value = getValue(dataObject);

    // TODO(terry): Add percent to display too.
/*
    final total = dataObject.controller.snapshots.last.snapshotGraph.capacity;
    final percentage = (value / total) * 100;
    final displayPercentage = percentage < .050 ? '<<1%'
        : '${NumberFormat.compact().format(percentage)}%';
    print('$displayPercentage [${NumberFormat.compact().format(percentage)}%]');
*/
    if ((dataObject.isAnalysis ||
            dataObject.isAllocations ||
            dataObject.isAllocation) &&
        value is! int) return '';

    return prettyPrintBytes(
      value as int,
      kbFractionDigits: 1,
      includeUnit: true,
    )!;
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }
}

// TODO(terry): Remove ignore when dominator is implemented.
// ignore: unused_element
class _RetainedSizeColumn extends ColumnData<Reference> {
  _RetainedSizeColumn()
      : super(
          'Retained',
          alignment: ColumnAlignment.right,
          fixedWidthPx: scaleByFontFactor(100.0),
        );

  @override
  dynamic getValue(Reference dataObject) {
    // Should never be empty when we're displaying in table.
    assert(!dataObject.isEmptyReference);

    if (dataObject.name == MemoryController.libraryRootNode ||
        dataObject.name == MemoryController.classRootNode) return '';

    if (dataObject.isLibrary) {
      // Return number of classes.
      final libraryReference = dataObject as LibraryReference;
      var sum = 0;
      for (final actualClass in libraryReference.actualClasses!) {
        sum += actualClass.instancesTotalShallowSizes;
      }
      return sum;
    } else if (dataObject.isClass) {
      final classReference = dataObject as ClassReference;
      return classReference.actualClass!.instancesTotalShallowSizes;
    } else if (dataObject.isObject) {
      // Return number of instances.
      final objectReference = dataObject as ObjectReference;
      return objectReference.instance.origin.shallowSize;
    } else if (dataObject.isExternals) {
      return dataObject.controller!.lastSnapshot!.snapshotGraph.externalSize;
    } else if (dataObject.isExternal) {
      return (dataObject as ExternalReference)
          .liveExternal
          .externalProperty
          .externalSize;
    }

    return '';
  }

  @override
  String getDisplayValue(Reference dataObject) {
    final value = getValue(dataObject);
    return '$value';
  }

  @override
  bool get supportsSorting => true;

  @override
  int compare(Reference a, Reference b) {
    // Analysis is always before.
    final Comparable valueA = a.isAnalysis ? 0 : getValue(a);
    final Comparable valueB = b.isAnalysis ? 0 : getValue(b);
    return valueA.compareTo(valueB);
  }
}
