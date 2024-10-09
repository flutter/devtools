// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../shared/diagnostics/diagnostics_node.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/ui/search.dart';

/// A log data object that includes optional summary information about whether
/// the log entry represents an error entry, the log entry kind, and more
/// detailed data for the entry.
///
/// The details can optionally be loaded lazily on first use. If this is the
/// case, this log entry will have a non-null `detailsComputer` field. After the
/// data is calculated, the log entry will be modified to contain the calculated
/// `details` data.
class LogDataV2 with SearchableDataMixin {
  LogDataV2(
    this.kind,
    this._details,
    this.timestamp, {
    this.summary,
    this.isError = false,
    this.detailsComputer,
    this.node,
  }) {
    // Fetch details immediately on creation.
    unawaited(compute());
  }

  final String kind;
  final int? timestamp;
  final bool isError;
  final String? summary;

  final RemoteDiagnosticsNode? node;
  String? _details;
  Future<String> Function()? detailsComputer;

  static const prettyPrinter = JsonEncoder.withIndent('  ');

  String? get details => _details;

  ValueListenable<bool> get detailsComputed => _detailsComputed;
  final _detailsComputed = ValueNotifier<bool>(false);

  Future<void> compute() async {
    if (!detailsComputed.value) {
      if (detailsComputer != null) {
        _details = await detailsComputer!();
      }
      detailsComputer = null;
      _detailsComputed.value = true;
    }
  }

  /// The current calculated display height.
  double? height;

  /// The current offset of this log entry in the logs table.
  double? offset;

  String? prettyPrinted() {
    if (!detailsComputed.value) {
      return details?.trim();
    }

    try {
      return prettyPrinter
          .convert(jsonDecode(details!))
          .replaceAll(r'\n', '\n')
          .trim();
    } catch (_) {
      return details?.trim();
    }
  }

  String asLogDetails() {
    return !detailsComputed.value ? '<fetching>' : prettyPrinted() ?? '';
  }

  @override
  bool matchesSearchToken(RegExp regExpSearch) {
    return kind.caseInsensitiveContains(regExpSearch) ||
        (summary?.caseInsensitiveContains(regExpSearch) == true) ||
        (details?.caseInsensitiveContains(regExpSearch) == true);
  }

  @override
  String toString() => 'LogData($kind, $timestamp)';
}
