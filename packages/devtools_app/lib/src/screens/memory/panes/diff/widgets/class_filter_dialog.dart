// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/class_filter.dart';
import '../controller/utils.dart';

class ClassFilterDialog extends StatefulWidget {
  const ClassFilterDialog(this.classFilter, {super.key});

  final ValueNotifier<ClassFilter> classFilter;

  @override
  State<ClassFilterDialog> createState() => _ClassFilterDialogState();
}

class _ClassFilterDialogState extends State<ClassFilterDialog> {
  bool _initialized = false;
  bool _showHelp = false;
  late String _rootPackage;

  late ClassFilterType _type;
  final _except = TextEditingController();
  final _only = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    assert(!_initialized);
    _rootPackage = await tryToDetectRootPackage() ?? '';
    _loadStateFromFilter(widget.classFilter.value);
    setState(() => _initialized = true);
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
    _only.text = filter.only ?? _rootPackage;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return Progress();

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
              const Text('Choose and customize the filter.\n'
                  'List full or partial class names separated by new lines. For example:\n\n'
                  '  package:myPackage/src/myFolder/myLibrary.dart/MyClass\n'
                  '  MyClass\n'
                  '  package:myPackage/src/\n\n'
                  'Specify:\n'
                  '  - ${ClassFilter.coreLibrariesAlias} for core classes without package prefix\n'
                  '  - ${ClassFilter.dartAndFlutterLibrariesAlias} for "dart." and "package:" libraries published by Dart and Flutter orgs.'),
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
          label: 'OK',
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
        const DialogCancelButton(),
      ],
    );
  }
}
