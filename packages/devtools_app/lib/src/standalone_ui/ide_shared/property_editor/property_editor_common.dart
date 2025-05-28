// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

/// A text button that displays "Show more" or "Show less" depending on whether
/// it [isExpanded].
class ExpandableTextButton extends StatelessWidget {
  const ExpandableTextButton({
    super.key,
    required this.isExpanded,
    required this.onTap,
  });

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Text(
        isExpanded ? 'Show less' : 'Show more',
        style: theme.boldTextStyle.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}
