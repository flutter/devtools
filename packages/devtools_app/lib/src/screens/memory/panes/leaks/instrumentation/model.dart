// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

enum LeakType {
  /// Not disposed and garbage collected.
  notDisposed,

  /// Disposed and not garbage collected when expected.
  notGCed,

  /// Disposed and garbage collected later than expected.
  gcedLate,
}

LeakType _parseLeakType(String source) =>
    LeakType.values.firstWhere((e) => e.toString() == source);

/// Statistical information about found leaks.
class LeakSummary {
  LeakSummary(this.totals);

  factory LeakSummary.fromJson(Map<String, dynamic> json) => LeakSummary(
        json.map(
          (key, value) => MapEntry(_parseLeakType(key), int.parse(value)),
        ),
      );

  final Map<LeakType, int> totals;

  bool get isEmpty => totals.values.sum == 0;

  String toMessage() {
    return '${totals.values.sum} memory leak(s): '
        'not disposed: ${totals[LeakType.notDisposed]}, '
        'not GCed: ${totals[LeakType.notGCed]}, '
        'GCed late: ${totals[LeakType.gcedLate]}';
  }

  Map<String, dynamic> toJson() =>
      totals.map((key, value) => MapEntry(key.toString(), value.toString()));

  bool matches(LeakSummary? other) =>
      other != null && mapEquals(totals, other.totals);
}

/// Detailed information about found leaks.
class Leaks {
  Leaks(this.byType);

  factory Leaks.fromJson(Map<String, dynamic> json) => Leaks(
        json.map(
          (key, value) => MapEntry(
            _parseLeakType(key),
            (value as List)
                .cast<Map<String, dynamic>>()
                .map((e) => LeakReport.fromJson(e))
                .toList(growable: false),
          ),
        ),
      );
  final Map<LeakType, List<LeakReport>> byType;

  List<LeakReport> get notGCed => byType[LeakType.notGCed] ?? [];
  List<LeakReport> get notDisposed => byType[LeakType.notDisposed] ?? [];
  List<LeakReport> get gcedLate => byType[LeakType.gcedLate] ?? [];

  Map<String, dynamic> toJson() => byType.map(
        (key, value) =>
            MapEntry(key.toString(), value.map((e) => e.toJson()).toList()),
      );
}

/// Names for json fields.
class _JsonFields {
  static const String type = 'type';
  static const String details = 'details';
  static const String code = 'code';
}

/// Leak information, passed from application to DevTools and than extended by
/// DevTools after deeper analysis.
class LeakReport {
  LeakReport({
    required this.type,
    required this.details,
    required this.code,
  });

  factory LeakReport.fromJson(Map<String, dynamic> json) => LeakReport(
        type: json[_JsonFields.type],
        details:
            (json[_JsonFields.details] as List<dynamic>? ?? []).cast<String>(),
        code: json[_JsonFields.code],
      );

  final String type;
  final List<String> details;
  final int code;

  // The fields below do not need serialization as they are populated after.
  String? retainingPath;
  List<String>? detailedPath;

  Map<String, dynamic> toJson() => {
        _JsonFields.type: type,
        _JsonFields.details: details,
        _JsonFields.code: code,
      };

  static String iterableToYaml(
    String title,
    Iterable<LeakReport>? leaks, {
    String indent = '',
  }) {
    if (leaks == null || leaks.isEmpty) return '';

    return '''$title:
$indent  total: ${leaks.length}
$indent  objects:
${leaks.map((e) => e.toYaml('$indent    ')).join()}
''';
  }

  String toYaml(String indent) {
    final result = StringBuffer();
    result.writeln('$indent$type:');
    result.writeln('$indent  type: $type');
    result.writeln('$indent  identityHashCode: $code');
    if (details.isNotEmpty) {
      result.writeln('$indent  details: $details');
    }

    if (detailedPath != null) {
      result.writeln('$indent  retainingPath:');
      result.writeln(detailedPath!.map((s) => '$indent    - $s').join('\n'));
    } else if (retainingPath != null) {
      result.writeln('$indent  retainingPath: $retainingPath');
    }
    return result.toString();
  }
}
