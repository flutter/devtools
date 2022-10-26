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
  const ClassFilterDialog(
    this.classFilter, {
    super.key,
    required this.onChanged,
  });

  final ClassFilter classFilter;
  final Function(ClassFilter filter) onChanged;

  @override
  State<ClassFilterDialog> createState() => _ClassFilterDialogState();
}

class _ClassFilterDialogState extends State<ClassFilterDialog> {
  bool _initialized = false;
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
    if (_rootPackage.isNotEmpty) _rootPackage = '$_rootPackage/';
    _loadStateFromFilter(widget.classFilter);
    setState(() => _initialized = true);
  }

  @override
  void didUpdateWidget(covariant ClassFilterDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classFilter != widget.classFilter) {
      _loadStateFromFilter(widget.classFilter);
    }
  }

  void _loadStateFromFilter(ClassFilter filter) {
    _type = filter.filterType;
    _except.text = filter.except;
    _only.text = filter.only ?? _rootPackage;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const CenteredCircularProgressIndicator();

    final textFieldLeftPadding = scaleByFontFactor(40.0);
    void onTypeChanged(ClassFilterType? type) => setState(() => _type = type!);

    return StateUpdateDialog(
      title: 'Filter Classes and Packages',
      helpText: _helpText,
      onResetDefaults: () =>
          setState(() => _loadStateFromFilter(ClassFilter.empty())),
      onApply: () {
        final newFilter = ClassFilter(
          filterType: _type,
          except: _except.text,
          only: _only.text,
        );
        widget.onChanged(newFilter);
      },
      onCancel: null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioButton<ClassFilterType>(
            label: 'Show all classes',
            itemValue: ClassFilterType.all,
            groupValue: _type,
            onChanged: onTypeChanged,
          ),
          const SizedBox(height: defaultSpacing),
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
          const SizedBox(height: defaultSpacing),
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
    );
  }
}

const _helpText = 'Choose and customize the filter.\n'
    'List full or partial class names separated by new lines. For example:\n\n'
    '  package:myPackage/src/myFolder/myLibrary.dart/MyClass\n'
    '  MyClass\n'
    '  package:myPackage/src/\n\n'
    'Specify:\n'
    '  - ${ClassFilter.coreLibrariesAlias} for core classes without package prefix\n'
    '  - ${ClassFilter.dartAndFlutterLibrariesAlias} for "dart." and "package:" libraries published by Dart and Flutter orgs.';
