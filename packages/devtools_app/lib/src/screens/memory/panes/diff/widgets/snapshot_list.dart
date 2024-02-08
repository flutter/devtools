// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/primitives/utils.dart';
import '../controller/diff_pane_controller.dart';
import '../controller/item_controller.dart';

final _log = Logger('snapshot_list');

class SnapshotList extends StatelessWidget {
  const SnapshotList({Key? key, required this.controller}) : super(key: key);
  final DiffPaneController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OutlineDecoration.onlyBottom(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: denseSpacing,
              horizontal: densePadding,
            ),
            child: _ListControlPane(controller: controller),
          ),
        ),
        Expanded(
          child: _SnapshotListItems(controller: controller),
        ),
      ],
    );
  }
}

@visibleForTesting
const iconToTakeSnapshot = Icons.fiber_manual_record;

class _ListControlPane extends StatelessWidget {
  const _ListControlPane({Key? key, required this.controller})
      : super(key: key);

  final DiffPaneController controller;

  Future<void> _takeSnapshot(BuildContext context) async {
    try {
      await controller.takeSnapshot();
    } catch (e, trace) {
      _log.shout(e, e, trace);
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (context) => UnexpectedErrorDialog(
          additionalInfo:
              'Encountered an error while taking a heap snapshot:\n${e.runtimeType}\n$e\n$trace',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ToolbarAction(
          icon: iconToTakeSnapshot,
          size: defaultIconSize,
          tooltip: 'Take heap snapshot for the selected isolate',
          onPressed: () => unawaited(_takeSnapshot(context)),
        ),
        const SizedBox(width: densePadding),
        ValueListenableBuilder(
          valueListenable: controller.core.snapshots,
          builder: (context, snapshots, _) {
            return ToolbarAction(
              icon: Icons.delete,
              size: defaultIconSize,
              tooltip: 'Delete all snapshots',
              onPressed: controller.hasSnapshots
                  ? () {
                      ga.select(
                        gac.memory,
                        gac.MemoryEvent.diffClearSnapshots,
                      );
                      controller.clearSnapshots();
                    }
                  : null,
            );
          },
        ),
        const Spacer(),
        ToolbarAction(
          icon: Icons.file_upload,
          tooltip: 'Import snapshot(s) from disk',
          onPressed: () => unawaited(controller.importSnapshots()),
        ),
      ],
    );
  }
}

@visibleForTesting
class SnapshotListTitle extends StatelessWidget {
  const SnapshotListTitle({
    Key? key,
    required this.item,
    required this.index,
    required this.selected,
    required this.editIndex,
    required this.onEdit,
    required this.onEditingComplete,
    required this.onDelete,
  }) : super(key: key);

  final SnapshotItem item;

  final int index;

  final bool selected;

  /// The index in the list for the [SnapshotListTitle] actively being edited.
  final ValueListenable<int?> editIndex;

  /// Called when the 'Rename' context menu item is selected.
  final VoidCallback onEdit;

  /// Called when the snapshot name editing is complete.
  final VoidCallback onEditingComplete;

  /// Called when the 'Delete' context menu item is selected.
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theItem = item;
    final theme = Theme.of(context);

    late final Widget leading;
    final trailing = <Widget>[];
    if (theItem is SnapshotDocItem) {
      leading = Icon(
        Icons.help_outline,
        size: defaultIconSize,
        color: theme.colorScheme.onSurface,
      );
    } else if (theItem is SnapshotInstanceItem) {
      leading = Expanded(
        child: ValueListenableBuilder(
          valueListenable: editIndex,
          builder: (context, editIndex, _) {
            return _EditableSnapshotName(
              item: theItem,
              editMode: index == editIndex,
              onEditingComplete: onEditingComplete,
            );
          },
        ),
      );

      const menuButtonWidth =
          ContextMenuButton.defaultWidth + ContextMenuButton.densePadding;
      trailing.addAll([
        if (theItem.totalSize != null)
          Text(
            prettyPrintBytes(
              theItem.totalSize,
              includeUnit: true,
              kbFractionDigits: 1,
            )!,
          ),
        Padding(
          padding: const EdgeInsets.only(left: ContextMenuButton.densePadding),
          child: selected
              ? ContextMenuButton(
                  menuChildren: <Widget>[
                    MenuItemButton(
                      onPressed: onEdit,
                      child: const Text('Rename'),
                    ),
                    MenuItemButton(
                      onPressed: onDelete,
                      child: const Text('Delete'),
                    ),
                  ],
                )
              : const SizedBox(width: menuButtonWidth),
        ),
      ]);
    }

    return ValueListenableBuilder<bool>(
      valueListenable: theItem.isProcessing,
      builder: (_, isProcessing, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: denseRowSpacing),
        child: Row(
          children: [
            leading,
            if (isProcessing)
              CenteredCircularProgressIndicator(size: smallProgressSize)
            else
              ...trailing,
          ],
        ),
      ),
    );
  }
}

class _EditableSnapshotName extends StatefulWidget {
  const _EditableSnapshotName({
    required this.item,
    required this.editMode,
    required this.onEditingComplete,
  });

  final SnapshotInstanceItem item;

  final bool editMode;

  final VoidCallback onEditingComplete;

  @override
  State<_EditableSnapshotName> createState() => _EditableSnapshotNameState();
}

class _EditableSnapshotNameState extends State<_EditableSnapshotName>
    with AutoDisposeMixin {
  late final TextEditingController textEditingController;

  final textFieldFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    textEditingController = TextEditingController();
    textEditingController.text = widget.item.name;

    _updateFocus();
    addAutoDisposeListener(textFieldFocusNode, () {
      if (!textFieldFocusNode.hasPrimaryFocus) {
        textFieldFocusNode.unfocus();
        widget.onEditingComplete();
      }
    });
  }

  @override
  void dispose() {
    cancelListeners();
    textEditingController.dispose();
    textFieldFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_EditableSnapshotName oldWidget) {
    super.didUpdateWidget(oldWidget);
    textEditingController.text = widget.item.name;
    _updateFocus();
  }

  void _updateFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.editMode) {
        textFieldFocusNode.requestFocus();
      } else {
        textFieldFocusNode.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // TODO(polina-c): start using ellipsis when it is available, https://github.com/flutter/devtools/issues/7130
    return TextField(
      controller: textEditingController,
      focusNode: textFieldFocusNode,
      autofocus: true,
      showCursor: widget.editMode,
      enabled: widget.editMode,
      style: Theme.of(context).regularTextStyle,
      decoration: const InputDecoration(
        isDense: true,
        border: InputBorder.none,
      ),
      onChanged: (value) => widget.item.nameOverride = value,
      onSubmitted: _updateName,
    );
  }

  void _updateName(String value) {
    widget.item.nameOverride = value;
    widget.onEditingComplete();
    textFieldFocusNode.unfocus();
  }
}

class _SnapshotListItems extends StatefulWidget {
  const _SnapshotListItems({required this.controller});

  final DiffPaneController controller;

  @override
  State<_SnapshotListItems> createState() => _SnapshotListItemsState();
}

class _SnapshotListItemsState extends State<_SnapshotListItems>
    with AutoDisposeMixin {
  final _headerHeight = 1.2 * defaultRowHeight;

  final _scrollController = ScrollController();

  /// The index in the list for the snapshot name actively being edited.
  ValueListenable<int?> get editIndex => _editIndex;
  final _editIndex = ValueNotifier<int?>(null);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editIndex.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _SnapshotListItems oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _init();
  }

  void _init() {
    cancelListeners();
    addAutoDisposeListener(
      widget.controller.core.selectedSnapshotIndex,
      scrollIfLast,
    );
  }

  Future<void> scrollIfLast() async {
    final core = widget.controller.core;

    final newLength = core.snapshots.value.length;
    final newIndex = core.selectedSnapshotIndex.value;

    if (newIndex == newLength - 1) await _scrollController.autoScrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.controller.core;

    return MultiValueListenableBuilder(
      listenables: [
        core.snapshots,
        core.selectedSnapshotIndex,
      ],
      builder: (_, values, __) {
        final snapshots = values.first as List<SnapshotItem>;
        final selectedIndex = values.second as int;
        return ListView.builder(
          controller: _scrollController,
          itemCount: snapshots.length,
          itemExtent: defaultRowHeight,
          itemBuilder: (context, index) {
            final selected = selectedIndex == index;
            return Container(
              height: _headerHeight,
              color: selected
                  ? Theme.of(context).colorScheme.selectedRowBackgroundColor
                  : null,
              child: InkWell(
                canRequestFocus: false,
                onTap: () {
                  widget.controller.setSnapshotIndex(index);
                  _editIndex.value = null;
                },
                child: SnapshotListTitle(
                  item: snapshots[index],
                  index: index,
                  selected: selected,
                  editIndex: editIndex,
                  onEdit: () => _editIndex.value = index,
                  onEditingComplete: () => _editIndex.value = null,
                  onDelete: () {
                    if (_editIndex.value == index) {
                      _editIndex.value = null;
                    }
                    final item = widget.controller.core.snapshots.value[index];
                    widget.controller.deleteSnapshot(item);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
