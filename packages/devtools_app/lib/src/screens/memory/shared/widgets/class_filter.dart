// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../../shared/analytics/analytics.dart' as ga;
import '../../../../shared/analytics/constants.dart' as gac;
import '../../../../shared/common_widgets.dart';
import '../../../../shared/memory/class_name.dart';
import '../heap/class_filter.dart';

String _adaptRootPackageForFilter(String? rootPackage) {
  if (rootPackage == null || rootPackage.isEmpty) return '';
  return '$rootPackage/';
}

class ClassFilterButton extends StatelessWidget {
  ClassFilterButton(this.data, {super.key})
      : _rootPackage = _adaptRootPackageForFilter(data.rootPackage);

  final ClassFilterData data;
  final String _rootPackage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClassFilter>(
      valueListenable: data.filter,
      builder: (context, filter, _) {
        return DevToolsFilterButton(
          onPressed: () {
            ga.select(
              gac.memory,
              gac.MemoryEvent.diffSnapshotFilter,
            );

            unawaited(
              showDialog(
                context: context,
                builder: (context) => ClassFilterDialog(
                  filter,
                  onChanged: data.onChanged,
                  rootPackage: _rootPackage,
                ),
              ),
            );
          },
          isFilterActive: !filter.isEmpty,
          message: filter.buttonTooltip,
          outlined: false,
        );
      },
    );
  }
}

@visibleForTesting
class ClassFilterDialog extends StatefulWidget {
  const ClassFilterDialog(
    this.classFilter, {
    super.key,
    required this.onChanged,
    required this.rootPackage,
  });

  final ClassFilter classFilter;
  final Function(ClassFilter filter) onChanged;
  final String rootPackage;

  @override
  State<ClassFilterDialog> createState() => _ClassFilterDialogState();
}

class _ClassFilterDialogState extends State<ClassFilterDialog> {
  late ClassFilterType _type;
  final _except = TextEditingController();
  final _only = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStateFromFilter(widget.classFilter);
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
    _only.text = filter.only ?? widget.rootPackage;
  }

  @override
  Widget build(BuildContext context) {
    final textFieldLeftPadding = scaleByFontFactor(40.0);
    void onTypeChanged(ClassFilterType? type) => setState(() => _type = type!);

    RadioButton<ClassFilterType> radio(ClassFilterType type, String label) =>
        RadioButton<ClassFilterType>(
          label: label,
          itemValue: type,
          groupValue: _type,
          onChanged: onTypeChanged,
          radioKey: Key(type.toString()),
        );

    Widget textField(TextEditingController controller) => Padding(
          padding: EdgeInsets.only(left: textFieldLeftPadding),
          child: TextField(
            decoration: dialogTextFieldDecoration,
            keyboardType: TextInputType.multiline,
            maxLines: null,
            controller: controller,
          ),
        );

    return StateUpdateDialog(
      title: 'Filter Classes and Packages',
      helpBuilder: _helpBuilder,
      onResetDefaults: () {
        ga.select(
          gac.memory,
          gac.MemoryEvent.diffSnapshotFilterReset,
        );
        setState(() => _loadStateFromFilter(ClassFilter.empty()));
      },
      onApply: () {
        ga.select(
          gac.memory,
          '${gac.MemoryEvent.diffSnapshotFilterType}-$_type',
        );
        final newFilter = ClassFilter(
          filterType: _type,
          except: _except.text,
          only: _only.text,
        );
        widget.onChanged(newFilter);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          radio(ClassFilterType.showAll, 'Show all classes'),
          const SizedBox(height: defaultSpacing),
          radio(ClassFilterType.except, 'Show all classes except:'),
          textField(_except),
          const SizedBox(height: defaultSpacing),
          radio(ClassFilterType.only, 'Show only:'),
          textField(_only),
        ],
      ),
    );
  }
}

Widget _helpBuilder(BuildContext context) {
  final textStyle = DialogHelpText.textStyle(context);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(_helpText, style: textStyle),
      ...ClassType.values.map(
        (t) => Row(
          children: [
            t.icon,
            Text(
              ' ${t.alias} - for ${t.aliasDescription}',
              style: textStyle,
            ),
            CopyToClipboardControl(
              dataProvider: () => t.alias,
              size: tableIconSize,
            ),
          ],
        ),
      ),
    ],
  );
}

const _helpText = 'Choose and customize the filter.\n'
    'List full or partial class names separated by new lines. For example:\n\n'
    '  package:myPackage/src/myFolder/myLibrary.dart/MyClass\n'
    '  MyClass\n'
    '  package:myPackage/src/\n\n'
    'Use aliases to filter classes by type:\n';
