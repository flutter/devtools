// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:collection/collection.dart' show ListExtensions;
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:vm_service/vm_service.dart';

import '../../../shared/analytics/constants.dart' as gac;
import '../../../shared/primitives/utils.dart' show SortDirection;
import '../../../shared/table/table.dart' show FlatTable;
import '../../../shared/table/table_data.dart';
import '../../../shared/ui/common_widgets.dart';
import '../vm_developer_tools_screen.dart';
import 'queued_microtasks_controller.dart';

class RefreshQueuedMicrotasksButton extends StatelessWidget {
  const RefreshQueuedMicrotasksButton({super.key, required this.controller});

  final QueuedMicrotasksController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QueuedMicrotasksControllerStatus>(
      valueListenable: controller.status,
      builder: (_, status, _) {
        return RefreshButton(
          onPressed: status == QueuedMicrotasksControllerStatus.refreshing
              ? null
              : controller.refresh,
          tooltip:
              "Take a new snapshot of the selected isolate's microtask queue.",
          gaScreen: gac.vmTools,
          gaSelection: gac.refreshQueuedMicrotasks,
        );
      },
    );
  }
}

class RefreshQueuedMicrotasksInstructions extends StatelessWidget {
  const RefreshQueuedMicrotasksInstructions({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).regularTextStyle,
          children: const [
            TextSpan(text: 'Click the refresh button '),
            WidgetSpan(child: Icon(Icons.refresh, size: defaultIconSize)),
            TextSpan(
              text:
                  " to take a new snapshot of the selected isolate's "
                  'microtask queue.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Record containing details about a particular microtask that was in a
/// microtask queue snapshot, and an index representing how close to the front
/// of the queue that microtask was when the snapshot was taken.
///
/// In the response returned by the VM Service, microtasks are sorted in
/// ascending order of when they will be dequeued, i.e. the microtask that will
/// run earliest is at index 0 of the returned list. We use those indices of the
/// returned list to sort the entries of the microtask selector, so that they
/// they also appear in ascending order of when they will be dequeued.
typedef IndexedMicrotask = ({int index, Microtask microtask});

class _MicrotaskIdColumn extends ColumnData<IndexedMicrotask> {
  _MicrotaskIdColumn()
    : super.wide('Microtask ID', alignment: ColumnAlignment.center);

  @override
  int getValue(IndexedMicrotask indexedMicrotask) => indexedMicrotask.index;

  @override
  String getDisplayValue(IndexedMicrotask indexedMicrotask) =>
      indexedMicrotask.microtask.id!.toString();
}

class QueuedMicrotaskSelector extends StatelessWidget {
  const QueuedMicrotaskSelector({
    super.key,
    required List<IndexedMicrotask> indexedMicrotasks,
    required void Function(Microtask?) onMicrotaskSelected,
  }) : _indexedMicrotasks = indexedMicrotasks,
       _setSelectedMicrotask = onMicrotaskSelected;

  static final _idColumn = _MicrotaskIdColumn();
  final List<IndexedMicrotask> _indexedMicrotasks;
  final void Function(Microtask?) _setSelectedMicrotask;

  @override
  Widget build(BuildContext context) => FlatTable<IndexedMicrotask>(
    keyFactory: (IndexedMicrotask microtask) => ValueKey<int>(microtask.index),
    data: _indexedMicrotasks,
    dataKey: 'queued-microtask-selector',
    columns: [_idColumn],
    defaultSortColumn: _idColumn,
    defaultSortDirection: SortDirection.ascending,
    onItemSelected: (indexedMicrotask) =>
        _setSelectedMicrotask(indexedMicrotask?.microtask),
  );
}

class MicrotaskStackTraceView extends StatelessWidget {
  const MicrotaskStackTraceView({super.key, required selectedMicrotask})
    : _selectedMicrotask = selectedMicrotask;

  final Microtask? _selectedMicrotask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          height: defaultHeaderHeight,
          padding: const EdgeInsets.only(left: defaultSpacing),
          alignment: Alignment.centerLeft,
          child: OutlineDecoration.onlyBottom(
            child: const Row(
              children: [
                Text('Stack trace captured when microtask was enqueued'),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SelectionArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: denseRowSpacing,
                    horizontal: defaultSpacing,
                  ),
                  child: Text(
                    style: theme.fixedFontStyle,
                    _selectedMicrotask!.stackTrace.toString(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class QueuedMicrotasksView extends VMDeveloperView {
  const QueuedMicrotasksView()
    : super(title: 'Queued Microtasks', icon: Icons.pending_actions);

  @override
  bool get showIsolateSelector => true;

  @override
  Widget build(BuildContext context) => QueuedMicrotasksViewBody();
}

class QueuedMicrotasksViewBody extends StatelessWidget {
  QueuedMicrotasksViewBody({super.key});

  @visibleForTesting
  static final dateTimeFormat = DateFormat('HH:mm:ss.SSS (MM/dd/yy)');
  final controller = QueuedMicrotasksController();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RefreshQueuedMicrotasksButton(controller: controller),
        const SizedBox(height: denseRowSpacing),
        Expanded(
          child: OutlineDecoration(
            child: ValueListenableBuilder(
              valueListenable: controller.status,
              builder: (context, status, _) {
                if (status == QueuedMicrotasksControllerStatus.empty) {
                  return const RefreshQueuedMicrotasksInstructions();
                } else if (status ==
                    QueuedMicrotasksControllerStatus.refreshing) {
                  return const CenteredMessage(message: 'Refreshing...');
                } else {
                  return ValueListenableBuilder(
                    valueListenable: controller.queuedMicrotasks,
                    builder: (_, queuedMicrotasks, _) {
                      assert(queuedMicrotasks != null);
                      if (queuedMicrotasks == null) {
                        return const CenteredMessage(
                          message: 'Unexpected null value',
                        );
                      }

                      final indexedMicrotasks = queuedMicrotasks.microtasks!
                          .mapIndexed(
                            (index, microtask) =>
                                (index: index, microtask: microtask),
                          )
                          .toList();
                      final formattedTimestamp = dateTimeFormat.format(
                        DateTime.fromMicrosecondsSinceEpoch(
                          queuedMicrotasks.timestamp!,
                        ),
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: denseRowSpacing,
                              horizontal: defaultSpacing,
                            ),
                            child: Text(
                              'Viewing snapshot that was taken at '
                              '$formattedTimestamp.',
                            ),
                          ),
                          Expanded(
                            child: SplitPane(
                              axis: Axis.horizontal,
                              initialFractions: const [0.15, 0.85],
                              children: [
                                OutlineDecoration(
                                  child: QueuedMicrotaskSelector(
                                    indexedMicrotasks: indexedMicrotasks,
                                    onMicrotaskSelected:
                                        controller.setSelectedMicrotask,
                                  ),
                                ),
                                ValueListenableBuilder(
                                  valueListenable: controller.selectedMicrotask,
                                  builder: (_, selectedMicrotask, _) =>
                                      OutlineDecoration(
                                        child: selectedMicrotask == null
                                            ? const CenteredMessage(
                                                message:
                                                    'Select a microtask ID on '
                                                    'the left to see '
                                                    'information about the '
                                                    'corresponding microtask.',
                                              )
                                            : MicrotaskStackTraceView(
                                                selectedMicrotask:
                                                    selectedMicrotask,
                                              ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
