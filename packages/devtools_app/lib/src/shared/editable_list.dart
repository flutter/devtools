// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../primitives/utils.dart';
import 'common_widgets.dart';
import 'theme.dart';
import 'utils.dart';

/// A widget that displays the contents of [entries].
///
/// It provides an interface that allows for removing, adding,
/// and refreshing entries.
class EditableList extends StatefulWidget {
  EditableList({
    required this.entries,
    required this.textFieldLabel,
    this.isRefreshing,
    this.onRefreshTriggered,
    Function(String)? onEntryAdded,
    Function(String)? onEntryRemoved,
  })  : onEntryAdded = onEntryAdded ?? ((entry) => entries.add(entry)),
        onEntryRemoved = onEntryRemoved ?? ((entry) => entries.remove(entry));

  /// The values that will be displayed in the editable list.
  ///
  /// If [onEntryAdded] or [onEntryRemoved] are left with their defaults, then
  /// [entries] will automatically have the values added or removed, when
  /// entries are added or removed in the interface.
  final ListValueNotifier<String> entries;

  /// The description label for textfield where new entries
  /// will be typed.
  final String textFieldLabel;

  /// A listenable that will replace the refresh button with a spinner, when
  /// set to true.
  final ValueListenable<bool>? isRefreshing;

  /// Triggered when an entry is added, using the interface.
  ///
  /// When not overridden, the default behaviour adds the entry to [entries]
  late final Function(String) onEntryAdded;

  /// Triggered when an entry is removed, using the interface.
  ///
  /// When not overridden, the default behaviour removes the entry
  /// from [entries].
  late final Function(String) onEntryRemoved;

  /// Triggered when the refresh is triggered, using the interface.
  final Function()? onRefreshTriggered;

  @override
  State<StatefulWidget> createState() => _EditableListState();
}

class _EditableListState extends State<EditableList> {
  @override
  void initState() {
    super.initState();
    textFieldController = TextEditingController();
  }

  late final TextEditingController textFieldController;
  final FocusNode textFieldFocusNode = FocusNode();

  @override
  void dispose() {
    textFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder(
      firstListenable: widget.entries,
      secondListenable: widget.isRefreshing ?? ValueNotifier<bool>(false),
      builder: (_, __, ___, ____) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditableListActionBar(
              textFieldFocusNode: textFieldFocusNode,
              textFieldController: textFieldController,
              isRefreshing: widget.isRefreshing,
              textFieldLabel: widget.textFieldLabel,
              onEntryAdded: widget.onEntryAdded,
              onRefresh: widget.onRefreshTriggered,
            ),
            const SizedBox(height: denseSpacing),
            Expanded(
              child: _EditableListContentView(
                entries: widget.entries,
                onEntryRemoved: widget.onEntryRemoved,
              ),
            ),
          ],
        );
      },
    );
  }
}

@visibleForTesting
class EditableListActionBar extends StatelessWidget {
  const EditableListActionBar({
    Key? key,
    required this.textFieldFocusNode,
    required this.textFieldController,
    required this.isRefreshing,
    required this.textFieldLabel,
    required this.onEntryAdded,
    required this.onRefresh,
  }) : super(key: key);

  final FocusNode textFieldFocusNode;
  final TextEditingController textFieldController;
  final ValueListenable<bool>? isRefreshing;
  final String textFieldLabel;
  final Function(String) onEntryAdded;
  final Function()? onRefresh;

  void _addNewItem() {
    final value = textFieldController.value.text.trim();
    textFieldController.clear();
    if (value.isNotEmpty) {
      textFieldController.clear();
      onEntryAdded(value);
    }
    textFieldFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: defaultTextFieldHeight,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: defaultTextFieldHeight,
              child: TextField(
                focusNode: textFieldFocusNode,
                controller: textFieldController,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(denseSpacing),
                  border: const OutlineInputBorder(),
                  labelText: textFieldLabel,
                ),
                onSubmitted: (value) {
                  _addNewItem();
                },
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _addNewItem();
            },
            child: const Text(
              'Add',
            ), // TODO:(https://github.com/flutter/devtools/issues/4381)
          ),
          isRefreshing?.value ?? false
              ? Container(
                  width: defaultTextFieldHeight,
                  height: defaultTextFieldHeight,
                  child: const Padding(
                    padding: EdgeInsets.all(densePadding),
                    child: CircularProgressIndicator(),
                  ),
                )
              : RefreshButton(
                  onPressed: () {
                    if (onRefresh != null) {
                      onRefresh!();
                    }
                  },
                  minScreenWidthForTextBeforeScaling: double.maxFinite,
                ),
        ],
      ),
    );
  }
}

class _EditableListContentView extends StatelessWidget {
  _EditableListContentView({
    Key? key,
    required this.entries,
    required this.onEntryRemoved,
  }) : super(key: key);

  final ListValueNotifier<String> entries;
  final Function(String) onEntryRemoved;
  final ScrollController _listContentScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _listContentScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        itemCount: entries.value.length,
        itemBuilder: (context, index) {
          return EditableListRow(
            entry: entries.value[index],
            onEntryRemoved: onEntryRemoved,
          );
        },
      ),
    );
  }
}

@visibleForTesting
class EditableListRow extends StatelessWidget {
  const EditableListRow({
    Key? key,
    required this.entry,
    required this.onEntryRemoved,
  }) : super(key: key);

  final String entry;
  final Function(String) onEntryRemoved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: densePadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(entry),
          ),
          EditableListCopyDirectoryButton(
            value: entry,
          ),
          const SizedBox(width: denseSpacing),
          EditableListRemoveDirectoryButton(
            onPressed: () {
              onEntryRemoved(
                entry,
              );
            },
          ),
          const SizedBox(width: denseRowSpacing)
        ],
      ),
    );
  }
}

@visibleForTesting
class EditableListCopyDirectoryButton extends StatelessWidget {
  const EditableListCopyDirectoryButton({
    super.key,
    required this.value,
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: key,
      padding: EdgeInsets.zero,
      onPressed: () {
        copyToClipboard(value, 'Copied to clipboard.', context);
      },
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: const Icon(Icons.copy_outlined),
    );
  }
}

@visibleForTesting
class EditableListRemoveDirectoryButton extends StatelessWidget {
  const EditableListRemoveDirectoryButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: key,
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: const Icon(Icons.delete),
    );
  }
}
