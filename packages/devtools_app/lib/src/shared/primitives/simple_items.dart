// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Package name prefixes.
class PackagePrefixes {
  /// Packages from the core Dart libraries as they are listed
  /// in heap snapshot.
  static const dartInSnapshot = 'dart.';

  /// Packages from the core Dart libraries as they are listed
  /// in import statements.
  static const dart = 'dart:';

  /// Generic dart package.
  static const genericDartPackage = 'package:';

  /// Packages from the core Flutter libraries.
  static const flutterPackage = 'package:flutter/';

  /// The Flutter namespace in C++ that is part of the Flutter Engine code.
  static const flutterEngine = 'flutter::';

  /// dart:ui is the library for the Dart part of the Flutter Engine code.
  static const dartUi = 'dart:ui';
}

enum ScreenMetaData {
  inspector('inspector', 'Flutter Inspector'),
  performance('performance', 'Performance'),
  cpuProfiler('cpu-profiler', 'CPU Profiler'),
  memory('memory', 'Memory'),
  debugger('debugger', 'Debugger'),
  network('network', 'Network'),
  logging('logging', 'Logging'),
  provider('provider', 'Provider'),
  appSize('app-size', 'App Size'),
  vmTools('vm-tools', 'VM Tools'),
  simple('simple', '');

  const ScreenMetaData(this.id, this.title);

  final String id;

  final String title;
}

const String traceEventsFieldName = 'traceEvents';

const closureName = '<closure>';

const anonymousClosureName = '<anonymous closure>';

const _memoryDocUrl =
    'https://docs.flutter.dev/development/tools/devtools/memory';
const _consoleDocUrl =
    'https://docs.flutter.dev/development/tools/devtools/console';

enum DocLinks {
  chart(_memoryDocUrl, 'expandable-chart'),
  profile(_memoryDocUrl, 'profile-memory-tab'),
  diff(_memoryDocUrl, 'diff-snapshots-tab'),
  trace(_memoryDocUrl, 'trace-instances-tab'),
  console(_consoleDocUrl, null),
  ;

  const DocLinks(this.url, this.hash);

  final String url;
  final String? hash;
  String get value => '$url#$hash';
}
