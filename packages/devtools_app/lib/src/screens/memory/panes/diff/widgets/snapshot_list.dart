// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/primitives/auto_dispose.dart';
import '../../../../../shared/primitives/utils.dart';
import '../../../../../shared/table/table.dart';
import '../../../../../shared/theme.dart';
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
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isTakingSnapshot,
      builder: (_, isProcessing, __) {
        final clearAllEnabled = !isProcessing && controller.hasSnapshots;
        return Row(
          children: [
            ToolbarAction(
              icon: iconToTakeSnapshot,
              tooltip: 'Take heap snapshot for the selected isolate',
              onPressed: controller.isTakingSnapshot.value
                  ? null
                  : () => unawaited(_takeSnapshot(context)),
            ),
            ToolbarAction(
              icon: Icons.block,
              tooltip: 'Clear all snapshots',
              onPressed: clearAllEnabled
                  ? () {
                      ga.select(
                        gac.memory,
                        gac.MemoryEvent.diffClearSnapshots,
                      );
                      controller.clearSnapshots();
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _SnapshotListTitle extends StatelessWidget {
  const _SnapshotListTitle({
    Key? key,
    required this.item,
    required this.index,
    required this.editIndexNotifier,
    required this.onNameEdited,
  }) : super(key: key);

  final SnapshotItem item;

  final int index;

  final ValueNotifier<int?> editIndexNotifier;

  final VoidCallback onNameEdited;

  @override
  Widget build(BuildContext context) {
    final theItem = item;
    final theme = Theme.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: theItem.isProcessing,
      builder: (_, isProcessing, __) => Row(
        children: [
          const SizedBox(width: denseRowSpacing),
          if (theItem is SnapshotInstanceItem)
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: editIndexNotifier,
                builder: (context, editIndex, _) {
                  return _EditableSnapshotName(
                    item: theItem,
                    editMode: index == editIndex,
                    onEditingComplete: onNameEdited,
                  );
                },
              ),
            ),
          if (theItem is SnapshotInstanceItem && theItem.totalSize != null) ...[
            const SizedBox(width: densePadding),
            Text(
              prettyPrintBytes(
                theItem.totalSize,
                includeUnit: true,
                kbFractionDigits: 1,
              )!,
            ),
            const SizedBox(width: denseRowSpacing),
          ],
          if (theItem is SnapshotDocItem)
            Icon(
              Icons.help_outline,
              size: defaultIconSize,
              color: theme.colorScheme.onSurface,
            ),
          if (isProcessing) ...[
            CenteredCircularProgressIndicator(size: smallProgressSize),
            const SizedBox(width: denseRowSpacing),
          ],
        ],
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
    return TextField(
      controller: textEditingController,
      focusNode: textFieldFocusNode,
      autofocus: true,
      showCursor: widget.editMode,
      enabled: widget.editMode,
      style: Theme.of(context).textTheme.bodyMedium,
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

  final _contextMenuController = MenuController();

  /// The index in the list for the snapshot name actively being edited.
  final _editIndex = ValueNotifier<int?>(null);

  /// The 'y' position for the open context menu.
  double? _openContextMenuPosition;

  /// Whether [BrowserContextMenu.enabled] was initially set to true.
  ///
  /// We will manage the state of [BrowserContextMenu.enabled] while this widget
  /// is alive, and will return it to its original state upon disposal.
  bool _browserContextMenuWasEnabled = false;

  @override
  void initState() {
    super.initState();
    _init();
    _disableBrowserContextMenu();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _editIndex.dispose();
    _reenableBrowserContextMenu();
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

    return DualValueListenableBuilder<List<SnapshotItem>, int>(
      firstListenable: core.snapshots,
      secondListenable: core.selectedSnapshotIndex,
      builder: (_, snapshots, selectedIndex, __) {
        return GestureDetector(
          onSecondaryTapUp: _showContextMenu,
          onDoubleTapDown: _enterEditMode,
          child: MenuAnchor(
            controller: _contextMenuController,
            anchorTapClosesMenu: true,
            onClose: () => _openContextMenuPosition = null,
            menuChildren: <Widget>[
              MenuItemButton(
                onPressed: _setEditIndex,
                child: const Text('Rename'),
              ),
            ],
            child: ListView.builder(
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
                      _resetEditMode();
                    },
                    child: _SnapshotListTitle(
                      item: snapshots[index],
                      index: index,
                      editIndexNotifier: _editIndex,
                      onNameEdited: _resetEditMode,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _enterEditMode(TapDownDetails details) {
    _editIndex.value = _indexForPosition(details.localPosition.dy);
  }

  void _resetEditMode() {
    _editIndex.value = null;
  }

  void _setEditIndex() {
    if (_openContextMenuPosition == null) return;
    _editIndex.value = _indexForPosition(_openContextMenuPosition!);
  }

  int _indexForPosition(double dy) {
    return (_scrollController.offset + dy) ~/ defaultRowHeight;
  }

  void _showContextMenu(TapUpDetails details) {
    final tapY = details.localPosition.dy;
    final index = _indexForPosition(tapY);
    // Only show the context menu for heap snapshots in the list (e.g. not the
    // first 'info' item and not for a position that is out of range).
    if (index > 0 && index < widget.controller.core.snapshots.value.length) {
      _openContextMenuPosition = details.localPosition.dy;
      _contextMenuController.open(position: details.localPosition);
    } else {
      _openContextMenuPosition = null;
    }
  }

  void _disableBrowserContextMenu() {
    if (!kIsWeb) {
      // Does nothing on non-web platforms.
      return;
    }
    _browserContextMenuWasEnabled = BrowserContextMenu.enabled;
    if (_browserContextMenuWasEnabled) {
      unawaited(BrowserContextMenu.disableContextMenu());
    }
  }

  void _reenableBrowserContextMenu() {
    if (!kIsWeb) {
      // Does nothing on non-web platforms.
      return;
    }
    if (_browserContextMenuWasEnabled && !BrowserContextMenu.enabled) {
      unawaited(BrowserContextMenu.enableContextMenu());
    }
  }
}
