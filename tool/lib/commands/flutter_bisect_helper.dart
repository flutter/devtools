// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:io';

import 'package:path/path.dart' as path;

/// Finds the nearest package directory for [testPath] by walking upward until a
/// `pubspec.yaml` is found.
///
/// Returns null if none is found before the filesystem root.
String? findPackageDirectory(String testPath) {
  var dir = Directory(path.dirname(path.absolute(testPath)));
  while (true) {
    if (File(path.join(dir.path, 'pubspec.yaml')).existsSync()) {
      return dir.path;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return null;
    }
    dir = parent;
  }
}

/// Binary-searches [commits] (oldest → newest) for the first bad commit.
///
/// [isBad] returns true when the test fails at that commit.
///
/// Assumes:
/// - every commit before the first bad is good
/// - every commit from the first bad onward is bad
/// - [commits] is non-empty
String findFirstBadCommit(
  List<String> commits, {
  required bool Function(String commit) isBad,
}) {
  if (commits.isEmpty) {
    throw ArgumentError('commits must not be empty');
  }

  var lo = 0;
  var hi = commits.length - 1;
  while (lo < hi) {
    final mid = lo + ((hi - lo) ~/ 2);
    if (isBad(commits[mid])) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return commits[lo];
}

/// Async variant of [findFirstBadCommit] for real checkout/test callbacks.
Future<String> findFirstBadCommitAsync(
  List<String> commits, {
  required Future<bool> Function(String commit) isBad,
}) async {
  if (commits.isEmpty) {
    throw ArgumentError('commits must not be empty');
  }

  var lo = 0;
  var hi = commits.length - 1;
  while (lo < hi) {
    final mid = lo + ((hi - lo) ~/ 2);
    if (await isBad(commits[mid])) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  return commits[lo];
}
