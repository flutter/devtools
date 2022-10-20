// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import '../../../../../shared/common_widgets.dart';
import '../../../../../shared/dialogs.dart';
import '../../../../../shared/theme.dart';
import '../controller/model.dart';

class ClassFilterDialog extends StatefulWidget {
  const ClassFilterDialog(this.classFilter, {super.key});

  final ValueNotifier<ClassFilter> classFilter;

  @override
  State<ClassFilterDialog> createState() => _ClassFilterDialogState();
}

class _ClassFilterDialogState extends State<ClassFilterDialog> {
  late ClassFilterType _type;
  // late String _except;
  // late String _only;

  @override
  void initState() {
    super.initState();
    _type = widget.classFilter.value.filterType;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void onTypeChanged(ClassFilterType? type) => setState(() => _type = type!);

    return DevToolsDialog(
      title: dialogTitleText(theme, 'Filter Classes and Packages'),
      content: Container(
        width: defaultDialogWidth,
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
            RadioButton<ClassFilterType>(
              label: 'Show all classes except:',
              itemValue: ClassFilterType.except,
              groupValue: _type,
              onChanged: onTypeChanged,
            ),
            RadioButton<ClassFilterType>(
              label: 'Show only:',
              itemValue: ClassFilterType.only,
              groupValue: _type,
              onChanged: onTypeChanged,
            ),

          ],
        ),
      ),
      actions: [
        DialogCloseButton(),
      ],
    );
  }
}

