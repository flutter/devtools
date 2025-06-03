// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:vm_service/vm_service.dart';

import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/primitives/utils.dart' show SortDirection;
import '../../../../shared/table/table.dart' show FlatTable;
import '../../../../shared/table/table_data.dart';
import '../../../../shared/ui/common_widgets.dart' show RefreshButton;
import 'queued_microtasks_controller.dart';

class RefreshQueuedMicrotasksButton extends StatelessWidget {
  const RefreshQueuedMicrotasksButton({
    super.key,
    required QueuedMicrotasksController controller,
  }) : _controller = controller;

  final QueuedMicrotasksController _controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<QueuedMicrotasksControllerStatus>(
      valueListenable: _controller.status,
      builder: (_, status, _) {
        return RefreshButton(
          iconOnly: true,
          outlined: false,
          onPressed: status == QueuedMicrotasksControllerStatus.refreshing
              ? null
              : _controller.refresh,
          tooltip:
              "Take a new snapshot of the selected isolate's microtask queue.",
          gaScreen: gac.performance,
          gaSelection: gac.PerformanceEvents.refreshQueuedMicrotasks.name,
        );
      },
    );
  }
}

class QueuedMicrotasksTabControls extends StatelessWidget {
  const QueuedMicrotasksTabControls({
    super.key,
    required QueuedMicrotasksController controller,
  }) : _controller = controller;

  final QueuedMicrotasksController _controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [RefreshQueuedMicrotasksButton(controller: _controller)],
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
          children: [
            const TextSpan(text: 'Click the refresh button '),
            WidgetSpan(child: Icon(Icons.refresh, size: defaultIconSize)),
            const TextSpan(
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

// In the response returned by the VM Service, microtasks are sorted in
// ascending order of when they will be dequeued, i.e. the microtask that will
// run earliest is at index 0 of the returned list. We use those indices of the
// returned list to sort the entries of the microtask selector, so that they
// they also appear in ascending order of when they will be dequeued.
typedef IndexedMicrotask = (int, Microtask);

class _MicrotaskIdColumn extends ColumnData<IndexedMicrotask> {
  _MicrotaskIdColumn()
    : super.wide('Microtask ID', alignment: ColumnAlignment.center);

  @override
  int getValue(IndexedMicrotask indexedMicrotask) => indexedMicrotask.$1;

  @override
  String getDisplayValue(IndexedMicrotask indexedMicrotask) =>
      indexedMicrotask.$2.id!.toString();
}

class QueuedMicrotaskSelector extends StatelessWidget {
  const QueuedMicrotaskSelector({
    super.key,
    required List<IndexedMicrotask> indexedMicrotasks,
    required void Function(Microtask?) setSelectedMicrotask,
  }) : _indexedMicrotasks = indexedMicrotasks,
       _setSelectedMicrotask = setSelectedMicrotask;

  static final _idColumn = _MicrotaskIdColumn();
  final List<IndexedMicrotask> _indexedMicrotasks;
  final void Function(Microtask?) _setSelectedMicrotask;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: FlatTable<IndexedMicrotask>(
          keyFactory: (IndexedMicrotask microtask) =>
              ValueKey<int>(microtask.$1),
          data: _indexedMicrotasks,
          dataKey: 'queued-microtask-selector',
          columns: [_idColumn],
          defaultSortColumn: _idColumn,
          defaultSortDirection: SortDirection.ascending,
          onItemSelected: (indexedMicrotask) =>
              _setSelectedMicrotask(indexedMicrotask?.$2),
        ),
      ),
    ],
  );
}

class StackTraceView extends StatelessWidget {
  const StackTraceView({super.key, required selectedMicrotask})
    : _selectedMicrotask = selectedMicrotask;

  final Microtask? _selectedMicrotask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SizedBox.fromSize(
          size: Size.fromHeight(defaultHeaderHeight),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: defaultBorderSide(theme)),
            ),
            padding: const EdgeInsets.only(left: defaultSpacing),
            alignment: Alignment.centerLeft,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: denseRowSpacing,
                  horizontal: defaultSpacing,
                ),
                child: SelectableText(
                  style: theme.fixedFontStyle,
                  _selectedMicrotask!.stackTrace.toString(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class QueuedMicrotasksTabView extends StatefulWidget {
  const QueuedMicrotasksTabView({super.key, required this.controller});

  final QueuedMicrotasksController controller;

  @override
  State<QueuedMicrotasksTabView> createState() =>
      _QueuedMicrotasksTabViewState();
}

class _QueuedMicrotasksTabViewState extends State<QueuedMicrotasksTabView>
    with AutoDisposeMixin {
  static final _dateTimeFormat = DateFormat('HH:mm:ss.SSS (MM/dd/yy)');

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller.status,
      builder: (context, status, _) {
        if (status == QueuedMicrotasksControllerStatus.empty) {
          return const RefreshQueuedMicrotasksInstructions();
        } else if (status == QueuedMicrotasksControllerStatus.refreshing) {
          return Center(
            child: Text(
              style: Theme.of(context).regularTextStyle,
              'Refreshing...',
            ),
          );
        } else {
          return ValueListenableBuilder(
            valueListenable: widget.controller.queuedMicrotasks,
            builder: (_, queuedMicrotasks, _) {
              assert(queuedMicrotasks != null);

              final indexedMicrotasks = queuedMicrotasks!.microtasks!.indexed
                  .cast<IndexedMicrotask>()
                  .toList();
              final formattedTimestamp = _dateTimeFormat.format(
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
                      'Viewing snapshot that was taken at $formattedTimestamp.',
                    ),
                  ),
                  Expanded(
                    child: SplitPane(
                      axis: Axis.horizontal,
                      initialFractions: const [0.15, 0.85],
                      children: [
                        QueuedMicrotaskSelector(
                          indexedMicrotasks: indexedMicrotasks,
                          setSelectedMicrotask:
                              widget.controller.setSelectedMicrotask,
                        ),
                        ValueListenableBuilder(
                          valueListenable: widget.controller.selectedMicrotask,
                          builder: (_, selectedMicrotask, _) =>
                              selectedMicrotask == null
                              ? const Center(
                                  child: Text(
                                    'Select a microtask ID on the left '
                                    'to see information about the '
                                    'corresponding microtask.',
                                  ),
                                )
                              : StackTraceView(
                                  selectedMicrotask: selectedMicrotask,
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
    );
  }
}
