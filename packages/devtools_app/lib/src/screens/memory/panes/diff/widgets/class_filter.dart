// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../../shared/analytics/analytics.dart' as ga;
import '../../../../../shared/analytics/constants.dart' as gac;
import '../../../../../shared/common_widgets.dart';
import '../../../shared/heap/class_filter.dart';
import 'class_filter_dialog.dart';

class ClassFilterButton extends StatelessWidget {
  const ClassFilterButton({required this.filter, required this.onChanged});

  final ValueListenable<ClassFilter> filter;
  final Function(ClassFilter) onChanged;

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
                ),
              ),
            );
          },
          isFilterActive: !filter.isEmpty,
          message: filter.buttonTooltip,
        );
      },
    );
  }
}
