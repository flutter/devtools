// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../analytics/analytics.dart' as ga;
import '../../analytics/constants.dart' as analytics_constants;
import '../../config_specific/logger/logger.dart' as logger;
import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/globals.dart';
import '../../shared/split.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import '../../shared/theme.dart';
import '../../shared/utils.dart';
import '../../ui/search.dart';
import '../../ui/tab.dart';
import 'memory_allocation_table_view.dart';
import 'memory_analyzer.dart';
import 'memory_controller.dart';
import 'memory_filter.dart';
import 'memory_graph_model.dart';
import 'memory_heap_treemap.dart';
import 'memory_instance_tree_view.dart';
import 'memory_snapshot_models.dart';

const memorySearchFieldKeyName = 'MemorySearchFieldKey';

@visibleForTesting
final memorySearchFieldKey = GlobalKey(debugLabel: memorySearchFieldKeyName);

class HeapTree extends StatefulWidget {
  const HeapTree(
    this.controller,
  );

  final MemoryController controller;

  @override
  HeapTreeViewState createState() => HeapTreeViewState();
}

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

class HeapTreeViewState extends State<HeapTree>
    with
        AutoDisposeMixin,
        SearchFieldMixin<HeapTree>,
        TickerProviderStateMixin {
  @visibleForTesting
  static const searchButtonKey = Key('Snapshot Search');
  @visibleForTesting
  static const filterButtonKey = Key('Snapshot Filter');
  @visibleForTesting
  static const dartHeapAnalysisTabKey = Key('Dart Heap Analysis Tab');
  @visibleForTesting
  static const dartHeapAllocationsTabKey = Key('Dart Heap Allocations Tab');

  /// Below constants should match index for Tab index in DartHeapTabs.
  static const int analysisTabIndex = 0;
  static const int allocationsTabIndex = 1;

  static const _gaPrefix = 'memoryTab';

  static final List<Tab> dartHeapTabs = [
    DevToolsTab.create(
      key: dartHeapAnalysisTabKey,
      gaPrefix: _gaPrefix,
      tabName: 'Analysis',
    ),
    DevToolsTab.create(
      key: dartHeapAllocationsTabKey,
      gaPrefix: _gaPrefix,
      tabName: 'Allocations',
    ),
  ];

  bool _controllerInitialized = false;

  late MemoryController _controller;

  late TabController _tabController;

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

    _tabController = TabController(length: dartHeapTabs.length, vsync: this);
    addAutoDisposeListener(_tabController);

    _animation = _setupBubbleAnimationController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<MemoryController>(context);
    if (_controllerInitialized && newController == _controller) return;
    _controllerInitialized = true;
    _controller = newController;

    cancelListeners();

    addAutoDisposeListener(_controller.selectedSnapshotNotifier, () {
      setState(() {
        _controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(_controller.selectionSnapshotNotifier, () {
      setState(() {
        _controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(_controller.filterNotifier, () {
      setState(() {
        _controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(_controller.leafSelectedNotifier, () {
      setState(() {
        _controller.computeRoot();
      });
    });

    addAutoDisposeListener(_controller.leafAnalysisSelectedNotifier, () {
      setState(() {
        _controller.computeAnalysisInstanceRoot();
      });
    });

    addAutoDisposeListener(_controller.searchNotifier, () {
      _controller.closeAutoCompleteOverlay();
      _controller..setCurrentHoveredIndexValue(0);
    });

    addAutoDisposeListener(_controller.searchAutoCompleteNotifier, () {
      ga.select(
        analytics_constants.memory,
        analytics_constants.snapshotFilterDialog,
      );
      _controller.handleAutoCompleteOverlay(
        context: context,
        searchFieldKey: memorySearchFieldKey,
        onTap: selectTheMatch,
      );
    });

    addAutoDisposeListener(_controller.monitorAllocationsNotifier, () {
      setState(() {
        _controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(_controller.memoryTimeline.sampleAddedNotifier, () {
      autoSnapshot();
    });

    treeMapVisible = _controller.treeMapVisible.value;
    addAutoDisposeListener(_controller.treeMapVisible, () {
      setState(() {
        treeMapVisible = _controller.treeMapVisible.value;
      });
    });

    addAutoDisposeListener(_controller.lastMonitorTimestamp);
  }

  @override
  void dispose() {
    _animation.dispose();

    super.dispose();
  }

  /// Enable to output debugging information for auto-snapshot.
  /// WARNING: Do not checkin with this flag set to true.
  final debugSnapshots = false;

  /// Detect spike in memory usage if so do an automatic snapshot.
  void autoSnapshot() {
    final heapSample = _controller.memoryTimeline.sampleAddedNotifier.value!;
    final heapSum = heapSample.external + heapSample.used;
    heapMovingAverage.add(heapSum);

    final dateTimeFormat = DateFormat('HH:mm:ss.SSS');
    final startDateTime = dateTimeFormat
        .format(DateTime.fromMillisecondsSinceEpoch(heapSample.timestamp));

    if (debugSnapshots) {
      debugLogger('AutoSnapshot $startDateTime heapSum=$heapSum, '
          'first=${heapMovingAverage.dataSet.first}, '
          'mean=${heapMovingAverage.mean}');
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
          debugLogger('AutoSnapshot - RSS exceeded '
              '($rssPercentIncrease% increase) @ $startDateTime.');
        }
      }
    }

    if (!takeSnapshot && heapMovingAverage.hasSpike()) {
      final snapshotTime =
          Duration(milliseconds: spikeSnapshotTime ?? heapSample.timestamp);
      spikeSnapshotTime = heapSample.timestamp;
      takeSnapshot = true;
      logger.log('AutoSnapshot - memory spike @ $startDateTime} '
          'last snapshot ${(sampleTime - snapshotTime).inSeconds} seconds ago.');
      debugLogger('               '
          'heap @ last snapshot = $lastSnapshotMemoryTotal, '
          'heap total=$heapSum, RSS=${heapSample.rss}');
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
    } else if (_controller.snapshotByLibraryData != null) {
      snapshotDisplay =
          treeMapVisible ? MemoryHeapTreemap(_controller) : MemoryHeapTable();
    } else {
      snapshotDisplay = null;
    }

    return Padding(
      padding: const EdgeInsets.only(top: denseRowSpacing),
      child: Column(
        children: [
          const SizedBox(height: defaultSpacing),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TabBar(
                labelColor: themeData.textTheme.bodyText1!.color,
                isScrollable: true,
                controller: _tabController,
                tabs: HeapTreeViewState.dartHeapTabs,
              ),
              _buildSearchFilterControls(),
            ],
          ),
          const SizedBox(height: densePadding),
          Expanded(
            child: TabBarView(
              physics: defaultTabBarViewPhysics,
              controller: _tabController,
              children: [
                // Analysis Tab
                Column(
                  children: [
                    _buildSnapshotControls(themeData.textTheme),
                    const SizedBox(height: denseRowSpacing),
                    Expanded(
                      child: OutlineDecoration(
                        child: buildSnapshotTables(snapshotDisplay),
                      ),
                    ),
                  ],
                ),

                // Allocations Tab
                Column(
                  children: [
                    _buildAllocationsControls(),
                    const SizedBox(height: denseRowSpacing),
                    const Expanded(child: AllocationTableView()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSnapshotTables(Widget? snapshotDisplay) {
    if (snapshotDisplay == null) {
      // Display help text about how to collect data.
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Click the take heap snapshot button '),
            Icon(Icons.camera),
            Text(' to collect a graph of memory objects.'),
          ],
        ),
      );
    }

    final rightSideTable = _controller.isLeafSelected
        ? InstanceTreeView()
        : _controller.isAnalysisLeafSelected
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
              rightSideTable,
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
        style: textTheme.bodyText2,
        value: _controller.groupingBy.value,
        onChanged: (String? newValue) {
          setState(
            () {
              ga.select(
                analytics_constants.memory,
                '${analytics_constants.groupByPrefix}$newValue',
              );
              _controller.selectedLeaf = null;
              _controller.groupingBy.value = newValue!;
              if (_controller.snapshots.isNotEmpty) {
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
                onChanged: _controller.snapshotByLibraryData != null
                    ? (value) {
                        ga.select(
                          analytics_constants.memory,
                          '${analytics_constants.treemapToggle}-'
                          '${value ? 'show' : 'hide'}',
                        );
                        _controller.toggleTreeMapVisible(value);
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
                  _controller.groupByTreeTable.dataRoots.every((element) {
                    element.expandCascading();
                    return true;
                  });
                }
                // All nodes expanded - signal tree state  changed.
                _controller.treeChanged();
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
                  _controller.groupByTreeTable.dataRoots.every((element) {
                    element.collapseCascading();
                    return true;
                  });
                  if (_controller.instanceFieldsTreeTable != null) {
                    // We're collapsing close the fields table.
                    _controller.selectedLeaf = null;
                  }
                  // All nodes collapsed - signal tree state changed.
                  _controller.treeChanged();
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

  static const _updateCircleRadius = 8.0;

  Timer? removeUpdateBubble;

  Widget displayTimestampUpdateBubble() {
    // Build the bubble to show data has changed (new allocation data).
    final bubble = AnimatedBuilder(
      animation: _animation,
      builder: (context, widget) {
        double circleSize = _animation.value;
        if (_animation.status == AnimationStatus.reverse &&
            _animation.value < _updateCircleRadius) {
          circleSize = _updateCircleRadius;
          _animation.stop();

          // Keep the bubble displayed for a few seconds.
          removeUpdateBubble?.cancel();

          removeUpdateBubble = Timer(const Duration(seconds: 5), () {
            _controller.lastMonitorTimestamp.value =
                _controller.monitorTimestamp;
            removeUpdateBubble = null;
          });
        }
        final circleWidget = textWidgetWithUpdateCircle(
          _controller.monitorTimestamp == null
              ? 'No allocations tracked'
              : 'Allocations Tracked at ${MemoryController.formattedTimestamp(_controller.monitorTimestamp)}',
          style: Theme.of(context).colorScheme.italicTextStyle,
          size: _controller.lastMonitorTimestamp.value ==
                  _controller.monitorTimestamp
              ? 0
              : circleSize,
        );

        return circleWidget;
      },
    );

    // Start the animation running again, wobbly bubble.
    _animation.forward();

    return bubble;
  }

  Widget _buildAllocationsControls() {
    final updateCircle = displayTimestampUpdateBubble();

    return Row(
      children: [
        IconLabelButton(
          tooltip: 'Collect Allocation Statistics',
          imageIcon: trackImage(context),
          label: 'Track',
          onPressed: () async {
            ga.select(
              analytics_constants.memory,
              analytics_constants.trackAllocations,
            );
            await _allocationStart();
          },
        ),
        const SizedBox(width: denseSpacing),
        IconLabelButton(
          tooltip: 'Reset all accumulators',
          imageIcon: resetImage(context),
          label: 'Reset',
          onPressed: () async {
            ga.select(
              analytics_constants.memory,
              analytics_constants.resetAllocationAccumulators,
            );
            await _allocationReset();
          },
        ),
        const Spacer(),
        updateCircle,
      ],
    );
  }

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
            child: Text(text, style: style),
            width: textWidth + 10,
          ),
        ),
        Positioned(
          right: 0,
          child: Container(
            alignment: Alignment.topRight,
            width: size,
            height: size,
            child: const Icon(Icons.fiber_manual_record, size: 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[400],
            ),
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
          extentOffset: TextSpan(text: message).toPlainText().length),
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

  // WARNING: Do not checkin the debug flag set to true.
  final _debugAllocationMonitoring = false;

  Future<void> _allocationStart() async {
    // TODO(terry): Look at grouping by library or classes also filtering e.g.,
    // await controller.computeLibraries();
    _controller.memoryTimeline.addMonitorStartEvent();

    final allocationtimestamp = DateTime.now();
    final currentAllocations = await _controller.getAllocationProfile();

    if (_controller.monitorAllocations.isNotEmpty) {
      final previousSize = _controller.monitorAllocations.length;
      int previousIndex = 0;
      final currentSize = currentAllocations.length;
      int currentIndex = 0;
      while (currentIndex < currentSize && previousIndex < previousSize) {
        final previousAllocation =
            _controller.monitorAllocations[previousIndex];
        final currentAllocation = currentAllocations[currentIndex];

        if (previousAllocation.classRef.id == currentAllocation.classRef.id) {
          final instancesCurrent = currentAllocation.instancesCurrent;
          final bytesCurrent = currentAllocation.bytesCurrent;

          currentAllocation.instancesDelta = previousAllocation.instancesDelta +
              (instancesCurrent - previousAllocation.instancesCurrent);
          currentAllocation.bytesDelta = previousAllocation.bytesDelta +
              (bytesCurrent - previousAllocation.bytesCurrent);

          final instancesAccumulated = currentAllocation.instancesDelta;
          final bytesAccumulated = currentAllocation.bytesDelta;

          if (_debugAllocationMonitoring &&
              (instancesAccumulated != 0 || bytesAccumulated != 0)) {
            debugLogger('previous,index=[$previousIndex][$currentIndex] '
                'class ${currentAllocation.classRef.name}\n'
                '    instancesCurrent=$instancesCurrent, '
                '    instancesAccumulated=${currentAllocation.instancesDelta}\n'
                '    bytesCurrent=$bytesCurrent, '
                '    bytesAccumulated=${currentAllocation.bytesDelta}}\n');
          }

          previousIndex++;
          currentIndex++;
        } else {
          // Either a new class in currentAllocations or old that's no longer
          // active in previousAllocations.
          final currentClassId = currentAllocation.classRef.id;
          final ClassHeapDetailStats? first =
              _controller.monitorAllocations.firstWhereOrNull(
            (element) => element.classRef.id == currentClassId,
          );
          if (first != null) {
            // A class that no longer exist (live or sentinel).
            previousIndex++;
          } else {
            // New Class encountered in new AllocationProfile, don't increment
            // previousIndex.
            currentIndex++;
          }
        }
      }

      // Insure all entries from previous and current monitors were looked at.
      assert(previousSize == previousIndex, '$previousSize == $previousIndex');
      assert(currentSize == currentIndex, '$currentSize == $currentIndex');
    }

    _controller.monitorTimestamp = allocationtimestamp;
    _controller.monitorAllocations = currentAllocations;

    _controller.treeChanged();
  }

  Future<void> _allocationReset() async {
    _controller.memoryTimeline.addMonitorResetEvent();
    final currentAllocations = await _controller.resetAllocationProfile();

    // Reset all accumulators to zero.
    for (final classAllocation in currentAllocations) {
      classAllocation.bytesDelta = 0;
      classAllocation.instancesDelta = 0;
    }

    _controller.monitorAllocations = currentAllocations;
  }

  /// Match, found,  select it and process via ValueNotifiers.
  void selectTheMatch(String foundName) {
    ga.select(
      analytics_constants.memory,
      analytics_constants.autoCompleteSearchSelect,
    );

    setState(() {
      if (_tabController.index == allocationsTabIndex) {
        _controller.selectItemInAllocationTable(foundName);
      } else if (_tabController.index == analysisTabIndex &&
          snapshotDisplay is MemoryHeapTable) {
        _controller.groupByTreeTable.dataRoots.every((element) {
          element.collapseCascading();
          return true;
        });
      }
    });

    selectFromSearchField(_controller, foundName);
    clearSearchField(_controller);
  }

  bool get _isSearchable {
    // Analysis tab and Snapshot exist or 'Allocations' tab allocations are monitored.
    return (_tabController.index == analysisTabIndex && !treeMapVisible) ||
        (_tabController.index == allocationsTabIndex &&
            _controller.monitorAllocations.isNotEmpty);
  }

  Widget _buildSearchWidget(GlobalKey<State<StatefulWidget>> key) => Container(
        width: wideSearchTextWidth,
        height: defaultTextFieldHeight,
        child: buildAutoCompleteSearchField(
          controller: _controller,
          searchFieldKey: key,
          searchFieldEnabled: _isSearchable,
          shouldRequestFocus: _isSearchable,
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
            key: filterButtonKey,
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

    _controller.memoryTimeline.addSnapshotEvent(auto: !userGenerated);

    setState(() {
      snapshotState = SnapshotStatus.streaming;
    });

    final snapshotTimestamp = DateTime.now();

    final graph = await _controller.snapshotMemory();

    // No snapshot collected, disconnected/crash application.
    if (graph == null) {
      setState(() {
        snapshotState = SnapshotStatus.done;
      });
      _controller.selectedSnapshotTimestamp = DateTime.now();
      return;
    }

    final snapshotCollectionTime = DateTime.now();

    setState(() {
      snapshotState = SnapshotStatus.graphing;
    });

    // To debug particular classes add their names to the last
    // parameter classNamesToMonitor e.g., ['AppStateModel', 'Terry', 'TerryEntry']
    _controller.heapGraph = convertHeapGraph(
      _controller,
      graph,
      [],
    );
    final snapshotGraphTime = DateTime.now();

    setState(() {
      snapshotState = SnapshotStatus.grouping;
    });

    await doGroupBy();

    final root = _controller.computeAllLibraries(graph: graph)!;

    final snapshot = _controller.storeSnapshot(
      snapshotTimestamp,
      graph,
      root,
      autoSnapshot: !userGenerated,
    );

    final snapshotDoneTime = DateTime.now();

    _controller.selectedSnapshotTimestamp = snapshotTimestamp;

    debugLogger('Total Snapshot completed in'
        ' ${snapshotDoneTime.difference(snapshotTimestamp).inMilliseconds / 1000} seconds');
    debugLogger('  Snapshot collected in'
        ' ${snapshotCollectionTime.difference(snapshotTimestamp).inMilliseconds / 1000} seconds');
    debugLogger('  Snapshot graph built in'
        ' ${snapshotGraphTime.difference(snapshotCollectionTime).inMilliseconds / 1000} seconds');
    debugLogger('  Snapshot grouping/libraries computed in'
        ' ${snapshotDoneTime.difference(snapshotGraphTime).inMilliseconds / 1000} seconds');

    setState(() {
      snapshotState = SnapshotStatus.done;
    });

    _controller.buildTreeFromAllData();
    _analyze(snapshot: snapshot);
  }

  Future<void> doGroupBy() async {
    _controller.heapGraph!
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
      builder: (BuildContext context) => SnapshotFilterDialog(_controller),
      barrierDismissible: false,
    );
  }

  void _debugCheckAnalyses(DateTime currentSnapDateTime) {
    // Debug only check.
    assert(() {
      // Analysis already completed we're done.
      final foundMatch = _controller.completedAnalyses.firstWhereOrNull(
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
    }());
  }

  void _analyze({Snapshot? snapshot}) {
    final AnalysesReference analysesNode = _controller.findAnalysesNode()!;

    snapshot ??= _controller.computeSnapshotToAnalyze!;
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
    final collectedData = collect(_controller, snapshot);

    // Analyze the collected data.

    // 1. Analysis of memory image usage.
    imageAnalysis(_controller, analyzeSnapshot, collectedData);

    // Add to our list of completed analyses.
    _controller.completedAnalyses.add(analyzeSnapshot);

    // Expand the 'Analysis' node.
    if (!analysesNode.isExpanded) {
      analysesNode.expand();
    }

    // Select the snapshot just analyzed.
    _controller.selectionSnapshotNotifier.value = Selection(
      node: analyzeSnapshot,
      nodeIndex: analyzeSnapshot.index,
      scrollIntoView: true,
    );
  }

  // ignore: unused_element
  void _settings() {
    // TODO(terry): TBD
  }
}

/// Snapshot TreeTable
class MemoryHeapTable extends StatefulWidget {
  @override
  MemoryHeapTableState createState() => MemoryHeapTableState();
}

/// A table of the Memory graph class top-down call tree.
class MemoryHeapTableState extends State<MemoryHeapTable>
    with AutoDisposeMixin {
  late MemoryController _controller;
  bool _controllerInitialized = false;

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

    final newController = Provider.of<MemoryController>(context);
    if (_controllerInitialized && newController == _controller) return;
    _controller = newController;
    _controllerInitialized = true;

    cancelListeners();

    // Update the tree when the tree state changes e.g., expand, collapse, etc.
    addAutoDisposeListener(_controller.treeChangedNotifier, () {
      if (_controller.isTreeChanged) {
        setState(() {});
      }
    });

    // Update the tree when the memorySource changes.
    addAutoDisposeListener(_controller.selectedSnapshotNotifier, () {
      setState(() {
        _controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(_controller.filterNotifier, () {
      setState(() {
        _controller.computeAllLibraries(rebuild: true);
      });
    });

    addAutoDisposeListener(_controller.searchAutoCompleteNotifier);

    addAutoDisposeListener(_controller.selectTheSearchNotifier, _handleSearch);

    addAutoDisposeListener(_controller.searchNotifier, _handleSearch);
  }

  void _handleSearch() {
    final searchingValue = _controller.search;
    if (searchingValue.isNotEmpty) {
      if (_controller.selectTheSearch) {
        // Found an exact match.
        selectItemInTree(searchingValue);
        _controller.selectTheSearch = false;
        _controller.resetSearch();
        return;
      }

      // No exact match, return the list of possible matches.
      _controller.clearSearchAutoComplete();

      final matches = _snapshotMatches(searchingValue);

      // Remove duplicates and sort the matches.
      final normalizedMatches = matches.toSet().toList()..sort();
      // Use the top 10 matches:
      _controller.searchAutoComplete.value = normalizedMatches
          .sublist(
              0,
              min(
                topMatchesLimit,
                normalizedMatches.length,
              ))
          .map((match) => AutoCompleteMatch(match))
          .toList();
    }
  }

  List<String> _snapshotMatches(String searchingValue) {
    final matches = <String>[];

    final externalMatches = <String>[];
    final filteredMatches = <String>[];

    switch (_controller.groupingBy.value) {
      case MemoryController.groupByLibrary:
        final searchRoot = _controller.activeSnapshot;
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
              filteredMatches.addAll(matchesInLibrary(
                library as LibraryReference,
                searchingValue,
              ));
            }
          }
        }
        break;
      case MemoryController.groupByClass:
        matches.addAll(matchClasses(
            _controller.groupByTreeTable.dataRoots, searchingValue));
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
    switch (_controller.groupingBy.value) {
      case MemoryController.groupByLibrary:
        final searchRoot = _controller.activeSnapshot;
        if (_controller.selectionSnapshotNotifier.value.node == null) {
          // No selected node, then select the snapshot we're searching.
          _controller.selectionSnapshotNotifier.value = Selection(
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
        for (final reference in _controller.groupByTreeTable.dataRoots) {
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
      _controller.selectionSnapshotNotifier.value = Selection(
        node: reference,
        nodeIndex: reference.index,
        scrollIntoView: true,
      );
      _controller.clearSearchAutoComplete();
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
    final root = _controller.buildTreeFromAllData();

    if (root != null && root.children.isNotEmpty) {
      // Snapshots and analyses exists display the trees.
      _controller.groupByTreeTable = TreeTable<Reference>(
        dataRoots: root.children,
        columns: _columns,
        treeColumn: _treeColumn,
        keyFactory: (libRef) => PageStorageKey<String?>(libRef.name),
        sortColumn: _columns[0],
        sortDirection: SortDirection.ascending,
        selectionNotifier: _controller.selectionSnapshotNotifier,
      );

      return _controller.groupByTreeTable;
    } else {
      // Nothing collected yet (snapshots/analyses) - return an empty area.
      return const SizedBox();
    }
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

  @override
  double get fixedWidthPx => 250.0;
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

    return NumberFormat.compact().format(value);
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
