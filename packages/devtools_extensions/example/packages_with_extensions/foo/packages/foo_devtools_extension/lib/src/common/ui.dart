// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Header widget for each example section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.number,
    required this.title,
    this.requirements,
    super.key,
  });

  final int number;
  final String title;
  final String? requirements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $title',
          style: theme.textTheme.titleMedium,
        ),
        if (requirements != null)
          Text(
            requirements!,
            style: theme.textTheme.titleSmall!.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
      ],
    );
  }
}
