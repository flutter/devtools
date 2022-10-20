// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/utils.dart';
import '../controller/filter.dart';

class ClassFilterDialog extends StatefulWidget {
  const ClassFilterDialog(this.classFilter, {super.key});

  final ValueNotifier<ClassFilter> classFilter;

  @override
  State<ClassFilterDialog> createState() => _ClassFilterDialogState();
}

class _ClassFilterDialogState extends State<ClassFilterDialog> {
  late ClassFilterType _type;
  final _except = TextEditingController();
  final _only = TextEditingController();
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _loadStateFromFilter(widget.classFilter.value);
  }

  @override
  void didUpdateWidget(covariant ClassFilterDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classFilter.value != widget.classFilter.value) {
      _loadStateFromFilter(widget.classFilter.value);
    }
  }

  void _loadStateFromFilter(ClassFilter filter) {
    _type = filter.filterType;
    _except.text = filter.except;
    _only.text = filter.only;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textFieldLeftPadding = scaleByFontFactor(40.0);
    final itemSpacing = scaleByFontFactor(28.0);

    void onTypeChanged(ClassFilterType? type) => setState(() => _type = type!);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'Filter Classes and Packages'),
      content: Container(
        width: defaultDialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconLabelButton(
              tooltip: _showHelp ? 'Hide help' : 'Show help',
              icon: _showHelp
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              label: 'Help',
              onPressed: () => setState(() => _showHelp = !_showHelp),
            ),
            if (_showHelp) ...[
              const SizedBox(height: denseSpacing),
              // TODO (polina-c): apply editor's changes from go/help-for-class-filters.
              const Text('Choose and customize the filter.\n'
                  'List full or partial class names separated by new lines. For example:\n\n'
                  '  package:myPackage/src/myFolder/myLibrary.dart/MyClass\n'
                  '  MyClass\n'
                  '  package:myPackage/src/\n\n'
                  'Specify "standard-libraries” for standard Dart and Flutter classes.'),
            ],
            SizedBox(height: itemSpacing),
            RadioButton<ClassFilterType>(
              label: 'Show all classes',
              itemValue: ClassFilterType.all,
              groupValue: _type,
              onChanged: onTypeChanged,
            ),
            SizedBox(height: itemSpacing),
            RadioButton<ClassFilterType>(
              label: 'Show all classes except:',
              itemValue: ClassFilterType.except,
              groupValue: _type,
              onChanged: onTypeChanged,
            ),
            Padding(
              padding: EdgeInsets.only(left: textFieldLeftPadding),
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                controller: _except,
              ),
            ),
            SizedBox(height: itemSpacing),
            RadioButton<ClassFilterType>(
              label: 'Show only:',
              itemValue: ClassFilterType.only,
              groupValue: _type,
              onChanged: onTypeChanged,
            ),
            Padding(
              padding: EdgeInsets.only(left: textFieldLeftPadding),
              child: TextField(
                keyboardType: TextInputType.multiline,
                maxLines: null,
                controller: _only,
              ),
            ),
          ],
        ),
      ),
      actions: [
        DialogTextButton(
          onPressed: () =>
              setState(() => _loadStateFromFilter(ClassFilter.empty())),
          child: const Text('Reset Defaults'),
        ),
        DialogCloseButton(
          onClose: () {
            final newFilter = ClassFilter(
              filterType: _type,
              except: _except.text,
              only: _only.text,
            );
            if (newFilter.equals(widget.classFilter.value)) return;
            widget.classFilter.value = newFilter;
          },
        ),
      ],
    );
  }
}
