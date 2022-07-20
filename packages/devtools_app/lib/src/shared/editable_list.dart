import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'theme.dart';
import 'utils.dart';

class EditableList extends StatefulWidget {
  EditableList({
    required this.entries,
    required this.textFieldLabel,
    this.isRefreshing,
    this.onEntryAdded,
    this.onEntryRemoved,
    this.onRefresh,
  });

  final ValueListenable<List<String>> entries;
  final ValueListenable<bool>? isRefreshing;
  final Function(String)? onEntryAdded;
  final Function(String)? onEntryRemoved;
  final Function()? onRefresh;
  final String textFieldLabel;
  final GlobalKey textFieldKey = GlobalKey();
  final GlobalKey addEntryButtonKey = GlobalKey();
  final GlobalKey removeEntryButtonKey = GlobalKey();
  final GlobalKey refreshButtonKey = GlobalKey();

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
            _EditableListActionBar(
              textFieldFocusNode: textFieldFocusNode,
              textFieldController: textFieldController,
              isRefreshing: widget.isRefreshing,
              textFieldLabel: widget.textFieldLabel,
              textFieldKey: widget.textFieldKey,
              addEntryButtonKey: widget.addEntryButtonKey,
              refreshButtonKey: widget.refreshButtonKey,
              onEntryAdded: widget.onEntryAdded,
              onRefresh: widget.onRefresh,
            ),
            Flexible(
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

class _EditableListActionBar extends StatelessWidget {
  const _EditableListActionBar({
    Key? key,
    required this.textFieldFocusNode,
    required this.textFieldController,
    required this.isRefreshing,
    required this.textFieldLabel,
    required this.textFieldKey,
    required this.addEntryButtonKey,
    required this.refreshButtonKey,
    required this.onEntryAdded,
    required this.onRefresh,
  }) : super(key: key);

  final FocusNode textFieldFocusNode;
  final TextEditingController textFieldController;
  final ValueListenable<bool>? isRefreshing;
  final String textFieldLabel;
  final GlobalKey textFieldKey;
  final GlobalKey addEntryButtonKey;
  final GlobalKey refreshButtonKey;
  final Function(String)? onEntryAdded;
  final Function()? onRefresh;

  void _addNewItem() {
    final value = textFieldController.value.text.trim();
    textFieldController.clear();
    if (onEntryAdded != null && value.isNotEmpty) {
      textFieldController.clear();
      onEntryAdded!(value);
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
                key: textFieldKey,
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
            key: addEntryButtonKey,
            onPressed: () {
              _addNewItem();
            },
            child: const Text('Add'),
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
                  key: refreshButtonKey,
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
  const _EditableListContentView({
    Key? key,
    required this.entries,
    required this.onEntryRemoved,
  }) : super(key: key);

  final ValueListenable<List<String>> entries;
  final Function(String)? onEntryRemoved;

  @override
  Widget build(BuildContext context) {
    return RoundedOutlinedBorder(
      child: Scrollbar(
        child: ListView.builder(
          itemCount: entries.value.length,
          itemBuilder: (context, index) {
            return EditableListRow(
              entry: entries.value[index],
              onEntryRemoved: onEntryRemoved,
            );
          },
        ),
      ),
    );
  }
}

class EditableListRow extends StatelessWidget {
  EditableListRow({
    Key? key,
    required this.entry,
    required this.onEntryRemoved,
  }) : super(key: key);

  final copyButtonKey = GlobalKey();
  final removeButtonKey = GlobalKey();
  final String entry;
  final Function(String)? onEntryRemoved;

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
          _CopyDirectoryButton(
            key: copyButtonKey,
            value: entry,
          ),
          const SizedBox(width: denseSpacing),
          _RemoveDirectoryButton(
            key: removeButtonKey,
            onPressed: () {
              if (onEntryRemoved != null) {
                onEntryRemoved!(
                  entry,
                );
              }
            },
          ),
          const SizedBox(width: denseRowSpacing)
        ],
      ),
    );
  }
}

class _CopyDirectoryButton extends StatelessWidget {
  const _CopyDirectoryButton({
    super.key,
    required this.value,
  });

  final String value;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: key,
      padding: const EdgeInsets.all(0.0),
      onPressed: () {
        copyToClipboard(value, 'Copied to clipboard.', context);
      },
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: const Icon(Icons.copy),
    );
  }
}

class _RemoveDirectoryButton extends StatelessWidget {
  const _RemoveDirectoryButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: key,
      padding: const EdgeInsets.all(0.0),
      onPressed: onPressed,
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: const Icon(Icons.delete),
    );
  }
}
