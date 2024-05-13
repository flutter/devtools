// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

/// Header widget for each example section.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.number, required this.title, super.key});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAzisSize.min,
      children: [
        Text(
          '$number. $title',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const PaddedDivider.thin(),
      ],
    );
  }
}
