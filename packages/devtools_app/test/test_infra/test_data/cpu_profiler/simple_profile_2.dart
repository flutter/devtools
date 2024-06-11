// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

final simpleCpuProfile2 = <String, Object?>{
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'stackDepth': 128,
  'sampleCount': 10,
  'timeOriginMicros': 0,
  'timeExtentMicros': 10000,
  'stackFrames': _profileStackFrames,
  'traceEvents': _profileTraceEvents,
};

final _profileStackFrames = <String, Object?>{
  '140357727781376-1': {
    'category': 'Dart',
    'name': 'A',
    'parent': 'cpuProfileRoot',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/a.dart',
    'packageUri': 'package:my_app/src/a.dart',
    'sourceLine': 111,
  },
  '140357727781376-2': {
    'category': 'Dart',
    'name': 'B',
    'parent': '140357727781376-1',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/b.dart',
    'packageUri': 'package:my_app/src/b.dart',
    'sourceLine': 222,
  },
  '140357727781376-3': {
    'category': 'Dart',
    'name': 'C',
    'parent': '140357727781376-2',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/c.dart',
    'packageUri': 'package:my_app/src/c.dart',
    'sourceLine': 333,
  },
  '140357727781376-4': {
    'category': 'Dart',
    'name': 'D',
    'parent': '140357727781376-1',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/d.dart',
    'packageUri': 'package:my_app/src/d.dart',
    'sourceLine': 444,
  },
  '140357727781376-5': {
    'category': 'Dart',
    'name': 'C',
    'parent': '140357727781376-4',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/c.dart',
    'packageUri': 'package:my_app/src/c.dart',
    'sourceLine': 333,
  },
  '140357727781376-6': {
    'category': 'Dart',
    'name': 'F',
    'parent': '140357727781376-1',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/f.dart',
    'packageUri': 'package:my_app/src/f.dart',
    'sourceLine': 555,
  },
  '140357727781376-7': {
    'category': 'Dart',
    'name': 'B',
    'parent': '140357727781376-6',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/b.dart',
    'packageUri': 'package:my_app/src/b.dart',
    'sourceLine': 222,
  },
  '140357727781376-8': {
    'category': 'Dart',
    'name': 'C',
    'parent': '140357727781376-7',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/c.dart',
    'packageUri': 'package:my_app/src/c.dart',
    'sourceLine': 333,
  },
  '140357727781376-9': {
    'category': 'Dart',
    'name': 'A',
    'parent': '140357727781376-5',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/a.dart',
    'packageUri': 'package:my_app/src/a.dart',
    'sourceLine': 111,
  },
};

final _profileTraceEvents = <Map<String, Object?>>[
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 0,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-1',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 1000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-2',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 2000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-7',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 3000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-7',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 4000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-3',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 5000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-3',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 6000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-3',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 7000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-8',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 8000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-5',
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 9000,
    'cat': 'Dart',
    'args': <String, Object?>{
      'userTag': 'Default',
      'vmTag': 'VM',
    },
    'sf': '140357727781376-9',
  },
];

const simpleProfile2Golden = '''
  A - children: 3 - excl: 1 - incl: 10
    B - children: 1 - excl: 1 - incl: 4
      C - children: 0 - excl: 3 - incl: 3
    D - children: 1 - excl: 0 - incl: 2
      C - children: 1 - excl: 1 - incl: 2
        A - children: 0 - excl: 1 - incl: 1
    F - children: 1 - excl: 0 - incl: 3
      B - children: 1 - excl: 2 - incl: 3
        C - children: 0 - excl: 1 - incl: 1
''';

const simpleProfile2MethodTableGolden = '''
A - (package:my_app/src/a.dart:111) (10 samples)
  Callers:
    C - (package:my_app/src/c.dart:333) - 100.00%
  Callees:
    B - (package:my_app/src/b.dart:222) - 44.44%
    F - (package:my_app/src/f.dart:555) - 33.33%
    D - (package:my_app/src/d.dart:444) - 22.22%

B - (package:my_app/src/b.dart:222) (7 samples)
  Callers:
    A - (package:my_app/src/a.dart:111) - 57.14%
    F - (package:my_app/src/f.dart:555) - 42.86%
  Callees:
    C - (package:my_app/src/c.dart:333) - 100.00%

C - (package:my_app/src/c.dart:333) (6 samples)
  Callers:
    B - (package:my_app/src/b.dart:222) - 66.67%
    D - (package:my_app/src/d.dart:444) - 33.33%
  Callees:
    A - (package:my_app/src/a.dart:111) - 100.00%

F - (package:my_app/src/f.dart:555) (3 samples)
  Callers:
    A - (package:my_app/src/a.dart:111) - 100.00%
  Callees:
    B - (package:my_app/src/b.dart:222) - 100.00%

D - (package:my_app/src/d.dart:444) (2 samples)
  Callers:
    A - (package:my_app/src/a.dart:111) - 100.00%
  Callees:
    C - (package:my_app/src/c.dart:333) - 100.00%
''';
