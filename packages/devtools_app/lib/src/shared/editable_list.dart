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
    widget.isRefreshing?.addListener(_stateRefresher);
  }

  late final TextEditingController textFieldController;
  final FocusNode textFieldFocusNode = FocusNode();
  void _stateRefresher() {
    // trigger a state update when the refreshing state updates
    setState(() {});
  }

  @override
  void dispose() {
    textFieldController.dispose();
    widget.isRefreshing?.removeListener(_stateRefresher);
    super.dispose();
  }

  void _addNewPubRootDirecory() {
    final value = textFieldController.value.text.trim();
    textFieldController.clear();
    if (widget.onEntryAdded != null && value.isNotEmpty) {
      textFieldController.clear();
      widget.onEntryAdded!(value);
    }
    textFieldFocusNode.requestFocus();
  }

  Widget _copyDirectoryButton(String value) {
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
    return ValueListenableBuilder(
      valueListenable: widget.entries,
      builder: (context, value, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
            ),
            Flexible(
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
                            _copyDirectoryButton(widget.entries.value[index]),
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
            ),
          ],
        );
      },
    );
  }
}
