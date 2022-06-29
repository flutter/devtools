// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:collection/collection.dart';

/// Number of full GC cycles since start of tracking, where full GC cycle is
/// a set of GC events that, with high confidence, guarantees GC of an object
/// without retaining path.
typedef GCTime = int;

/// Distance between two [GCTime] values.
typedef GCDuration = int;

typedef ObjectDetailsProvider = String? Function(Object object);

const GCDuration cyclesToDeclareLeakIfNotGCed = 2;

const Duration delayToDeclareLeakIfNotGCed = Duration(seconds: 1);

/// Result of [identityHashCode].
typedef IdentityHashCode = int;

typedef Token = Object;

enum LeakType {
  notDisposed,
  notGCed,
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
    return 'Not disposed: ${totals[LeakType.notDisposed]}, '
        'not GCed: ${totals[LeakType.notGCed]}, '
        'GCed late: ${totals[LeakType.gcedLate]}, '
        'total: ${totals.values.sum}.';
  }

  bool equals(LeakSummary? other) {
    if (other == null) return false;
    return const MapEquality().equals(totals, other.totals);
  }

  Map<String, dynamic> toJson() =>
      totals.map((key, value) => MapEntry(key.toString(), value.toString()));
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

/// Leak information, passed from application to DevTools and than extended by
/// DevTools after deeper analysis.
class LeakReport {
  LeakReport({
    required this.token,
    required this.type,
    required this.details,
    required this.code,
  });

  factory LeakReport.fromJson(Map<String, dynamic> json) => LeakReport(
        token: json['token'],
        type: json['type'],
        details: json['details'],
        code: json['code'],
      );

  /// Token, provided by user.
  final String token;
  final String type;
  final String? details;
  final IdentityHashCode code;

  // The fields below do not need serialization as they are populated after.
  String? retainingPath;
  List<String>? detailedPath;

  Map<String, dynamic> toJson() => {
        'token': token,
        'type': type,
        'details': details,
        'code': code,
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
    result.writeln('$indent  token: $token');
    result.writeln('$indent  type: $type');
    result.writeln('$indent  details: $details');
    result.writeln('$indent  identityHashCode: $code');

    if (detailedPath != null) {
      result.writeln('$indent  retainingPath:');
      result.writeln(detailedPath!.map((s) => '$indent    - $s').join('\n'));
    } else if (retainingPath != null) {
      result.writeln('$indent  retainingPath: $retainingPath');
    }
    return result.toString();
  }
}

/// Information about an object that is needed to detect leaks.
class TrackedObjectInfo {
  TrackedObjectInfo(
    this.token,
    this.details,
    Object object,
  )   : type = object.runtimeType,
        code = identityHashCode(object);
  final Token token;
  final Type type;
  final String? details;
  final IdentityHashCode code;

  DateTime? _disposedTime;
  GCTime? _disposed;
  void setDisposed(GCTime value) {
    if (_disposed != null) throw 'The object $token disposed twice.';
    if (_gced != null)
      throw 'The object $token should not be disposed after being GCed.';
    _disposed = value;
    _disposedTime = DateTime.now();
  }

  DateTime? _gcedTime;
  GCTime? _gced;
  void setGCed(GCTime value) {
    if (_gced != null) throw 'The object $token GCed twice.';
    _gced = value;
    _gcedTime = DateTime.now();
  }

  bool get isGCed => _gced != null;
  bool get isDisposed => _disposed != null;

  bool get isGCedLateLeak {
    if (_disposed == null || _gced == null) return false;
    assert(_gcedTime != null);
    return _shouldDeclareGCLeak(_disposed, _disposedTime, _gced!, _gcedTime!);
  }

  bool isNotGCedLeak(GCTime now) {
    if (_gced != null) return false;
    return _shouldDeclareGCLeak(_disposed, _disposedTime, now, DateTime.now());
  }

  static bool _shouldDeclareGCLeak(
    GCTime? disposed,
    DateTime? disposedTime,
    GCTime gced,
    DateTime gcedTime,
  ) {
    assert((disposed == null) == (disposedTime == null));
    if (disposed == null || disposedTime == null) return false;

    return gced - disposed >= cyclesToDeclareLeakIfNotGCed &&
        gcedTime.difference(disposedTime) >= delayToDeclareLeakIfNotGCed;
  }

  bool get isNotDisposedLeak {
    return isGCed && !isDisposed;
  }

  LeakReport toLeakReport() => LeakReport(
        token: token.toString(),
        type: type.toString(),
        details: details,
        code: code,
      );
}
