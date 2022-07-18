import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'common_widgets.dart';
import 'theme.dart';
import 'utils.dart';

class EditableList extends StatefulWidget {
  const EditableList({
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
              widget: widget,
            ),
            _EditableListContentView(widget: widget),
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
    required this.widget,
  }) : super(key: key);
  void _addNewPubRootDirecory() {
    final value = textFieldController.value.text.trim();
    textFieldController.clear();
    if (widget.onEntryAdded != null && value.isNotEmpty) {
      textFieldController.clear();
      widget.onEntryAdded!(value);
    }
    textFieldFocusNode.requestFocus();
  }

  final FocusNode textFieldFocusNode;
  final TextEditingController textFieldController;
  final EditableList widget;

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
                  labelText: widget.textFieldLabel,
                ),
                onSubmitted: (value) {
                  _addNewPubRootDirecory();
                },
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _addNewPubRootDirecory();
            },
            child: const Text('Add'),
          ),
          widget.isRefreshing?.value ?? false
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
                    if (widget.onRefresh != null) {
                      widget.onRefresh!();
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
    required this.widget,
  }) : super(key: key);

  final EditableList widget;

  Widget _copyDirectoryButton(BuildContext context, String value) {
    return IconButton(
      padding: const EdgeInsets.all(0.0),
      onPressed: () {
        copyToClipboard(value, 'Copied to clipboard.', context);
      },
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: const Icon(Icons.copy),
    );
  }

  Widget _removeDirectoryButton(VoidCallback onPressed) {
    return IconButton(
      padding: const EdgeInsets.all(0.0),
      onPressed: onPressed,
      iconSize: defaultIconSize,
      splashRadius: defaultIconSize,
      icon: const Icon(Icons.delete),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: RoundedOutlinedBorder(
        child: Scrollbar(
          child: ListView.builder(
            itemCount: widget.entries.value.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: densePadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(widget.entries.value[index]),
                    ),
                    _copyDirectoryButton(context, widget.entries.value[index]),
                    const SizedBox(width: denseSpacing),
                    _removeDirectoryButton(
                      () {
                        if (widget.onEntryRemoved != null) {
                          widget.onEntryRemoved!(
                            widget.entries.value[index],
                          );
                        }
                      },
                    ),
                    const SizedBox(width: denseRowSpacing)
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
