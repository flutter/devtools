// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/theme.dart';
import '../../../../../shared/utils.dart';
import '../../../shared/heap/class_filter.dart';
import '../../../shared/primitives/class_name.dart';

class ClassFilterButton extends StatelessWidget {
  const ClassFilterButton({
    required this.filter,
    required this.onChanged,
    required this.rootPackage,
  });

  final ValueListenable<ClassFilter> filter;
  final Function(ClassFilter) onChanged;
  final String? rootPackage;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ClassFilter>(
      valueListenable: filter,
      builder: (context, filter, _) {
        return FilterButton(
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
                  onChanged: onChanged,
                  rootPackage: rootPackage,
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

String _adaptRootPackageForFilter(String? rootPackage) {
  rootPackage ??= '';
  if (rootPackage.isNotEmpty) rootPackage = '$rootPackage/';
  return rootPackage;
}

@visibleForTesting
class ClassFilterDialog extends StatefulWidget {
  ClassFilterDialog(
    this.classFilter, {
    super.key,
    required this.onChanged,
    required String? rootPackage,
  }) : adaptedRootPackage = _adaptRootPackageForFilter(rootPackage);

  final ClassFilter classFilter;
  final Function(ClassFilter filter) onChanged;
  final String adaptedRootPackage;

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
    _only.text = filter.only ?? widget.adaptedRootPackage;
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
            keyboardType: TextInputType.multiline,
            maxLines: null,
            controller: controller,
          ),
        );

    return StateUpdateDialog(
      title: 'Filter Classes and Packages',
      helpText: _helpText,
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

late final _helpText = () {
  final classTypesDescription = ClassType.values
      .map((t) => '  - ${t.alias} for ${t.aliasDescription}')
      .join('\n');

  return 'Choose and customize the filter.\n'
      'List full or partial class names separated by new lines. For example:\n\n'
      '  package:myPackage/src/myFolder/myLibrary.dart/MyClass\n'
      '  MyClass\n'
      '  package:myPackage/src/\n\n'
      'Use aliases to filter classes by type:\n'
      '$classTypesDescription';
}();
