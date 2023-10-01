// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../analytics/analytics.dart' as ga;
import '../common_widgets.dart';

/// A [DropDownButton] implementation that reports selection changes to our
/// analytics.
class AnalyticsDropDownButton<T> extends StatelessWidget {
  const AnalyticsDropDownButton({
    super.key,
    required this.gaScreen,
    required this.gaDropDownId,
    required this.message,
    required this.value,
    required this.items,
    required this.onChanged,
    this.sendAnalytics = true,
    this.isDense = false,
    this.isExpanded = false,
    this.roundedCornerOptions,
  });

  /// The GA ID for the screen this widget is displayed on.
  final String gaScreen;

  /// The GA ID for this widget.
  final String gaDropDownId;

  /// Whether to send analytics events to GA.
  ///
  /// Only set this to false if [AnalyticsDropDownButton] is being used for
  /// experimental code we do not want to send GA events for yet.
  final bool sendAnalytics;

  /// The message to be displayed in the widget's tooltip.
  final String? message;

  /// The currently selected value.
  final T? value;

  /// The list of options available in the drop down with their associated GA
  /// IDs.
  final List<({DropdownMenuItem<T> item, String gaId})>? items;

  /// Invoked when the selected drop down item has changed.
  final void Function(T?)? onChanged;

  final bool isDense;
  final bool isExpanded;
  final RoundedCornerOptions? roundedCornerOptions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultButtonHeight,
      child: DevToolsTooltip(
        message: message,
        child: RoundedDropDownButton<T>(
          isDense: isDense,
          isExpanded: isExpanded,
          style: Theme.of(context).textTheme.bodyMedium,
          value: value,
          items: items?.map((e) => e.item).toList(),
          onChanged: _onChanged,
          roundedCornerOptions: roundedCornerOptions,
        ),
      ),
    );
  }

  void _onChanged(T? newValue) {
    if (sendAnalytics && items != null) {
      final gaId =
          items?.firstWhereOrNull((element) => element.item == newValue)?.gaId;
      if (gaId != null) {
        ga.select(gaScreen, '$gaDropDownId $gaId');
      }
    }
    onChanged?.call(newValue);
  }
}
