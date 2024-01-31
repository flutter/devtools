// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'config_specific/copy_to_clipboard/copy_to_clipboard.dart';

/// A widget that displays the contents of [entries].
///
/// It provides an interface that allows for removing, adding,
/// and refreshing entries.
class EditableList extends StatefulWidget {
  EditableList({
    super.key,
    required this.entries,
    required this.textFieldLabel,
    required this.gaScreen,
    required this.gaRefreshSelection,
    this.isRefreshing,
    this.onRefreshTriggered,
    void Function(String)? onEntryAdded,
    void Function(String)? onEntryRemoved,
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
  late final void Function(String) onEntryAdded;

  /// Triggered when an entry is removed, using the interface.
  ///
  /// When not overridden, the default behaviour removes the entry
  /// from [entries].
  late final void Function(String) onEntryRemoved;

  /// Triggered when the refresh is triggered, using the interface.
  final void Function()? onRefreshTriggered;

  final String gaScreen;

  final String gaRefreshSelection;

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
    return MultiValueListenableBuilder(
      listenables: [
        widget.entries,
        widget.isRefreshing ?? ValueNotifier<bool>(false),
      ],
      builder: (_, __, ____) {
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
              gaScreen: widget.gaScreen,
              gaRefreshSelection: widget.gaRefreshSelection,
            ),
            const SizedBox(height: defaultSpacing),
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
    required this.gaScreen,
    required this.gaRefreshSelection,
  }) : super(key: key);

  final FocusNode textFieldFocusNode;
  final TextEditingController textFieldController;
  final ValueListenable<bool>? isRefreshing;
  final String textFieldLabel;
  final void Function(String) onEntryAdded;
  final void Function()? onRefresh;
  final String gaScreen;
  final String gaRefreshSelection;

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
    return SizedBox(
      height: defaultTextFieldHeight,
      child: Row(
        children: [
          Expanded(
            child: DevToolsClearableTextField(
              controller: textFieldController,
              labelText: textFieldLabel,
              onSubmitted: (value) {
                _addNewItem();
              },
            ),
          ),
          const SizedBox(width: densePadding),
          TextButton(
            onPressed: () {
              _addNewItem();
            },
            child: const Text(
              'Add',
            ), // TODO:(https://github.com/flutter/devtools/issues/4381)
          ),
          const SizedBox(width: densePadding),
          isRefreshing?.value ?? false
              ? SizedBox(
                  width: defaultTextFieldHeight,
                  height: defaultTextFieldHeight,
                  child: const Padding(
                    padding: EdgeInsets.all(densePadding),
                    child: CircularProgressIndicator(),
                  ),
                )
              : RefreshButton(
                  gaScreen: gaScreen,
                  gaSelection: gaRefreshSelection,
                  onPressed: onRefresh,
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
  final void Function(String) onEntryRemoved;
  final ScrollController _listContentScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _listContentScrollController,
      thumbVisibility: true,
      child: ListView.builder(
        controller: _listContentScrollController,
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
  final void Function(String) onEntryRemoved;

  @override
  Widget build(BuildContext context) {
    return Row(
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
      ],
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
    return DevToolsButton.iconOnly(
      icon: Icons.copy_outlined,
      outlined: false,
      onPressed: () {
        unawaited(copyToClipboard(value, 'Copied to clipboard.'));
      },
    );
  }
}

@visibleForTesting
class EditableListRemoveDirectoryButton extends StatelessWidget {
  const EditableListRemoveDirectoryButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DevToolsButton.iconOnly(
      icon: Icons.delete,
      outlined: false,
      onPressed: onPressed,
    );
  }
}
