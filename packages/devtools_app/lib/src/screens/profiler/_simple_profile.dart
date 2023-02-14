final Map<String, dynamic> simpleCpuProfile = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'stackDepth': 128,
  'sampleCount': 10,
  'timeOriginMicros': 0,
  'timeExtentMicros': 10000,
  'stackFrames': _profileStackFrames,
  'traceEvents': _profileTraceEvents,
};

final _profileStackFrames = {
  '140357727781376-1': {
    'category': 'Dart',
    'name': 'A',
    'parent': 'cpuProfileRoot',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/a.dart',
    'packageUri': 'package:my_app/my_app.dart',
    'sourceLine': null,
  },
  '140357727781376-2': {
    'category': 'Dart',
    'name': 'B',
    'parent': '140357727781376-1',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/b.dart',
    'packageUri': 'package:my_app/my_app.dart',
    'sourceLine': null,
  },
  '140357727781376-3': {
    'category': 'Dart',
    'name': 'C',
    'parent': '140357727781376-2',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/c.dart',
    'packageUri': 'package:my_app/my_app.dart',
    'sourceLine': null,
  },
  '140357727781376-4': {
    'category': 'Dart',
    'name': 'D',
    'parent': '140357727781376-1',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/d.dart',
    'packageUri': 'package:my_app/my_app.dart',
    'sourceLine': null,
  },
  '140357727781376-5': {
    'category': 'Dart',
    'name': 'C',
    'parent': '140357727781376-4',
    'resolvedUrl': 'path/to/my_app/packages/my_app/lib/src/c.dart',
    'packageUri': 'package:my_app/my_app.dart',
    'sourceLine': null,
  },
};

final List<Map<String, dynamic>> _profileTraceEvents = [
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
    'sf': '140357727781376-1'
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
    'sf': '140357727781376-2'
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
    'sf': '140357727781376-2'
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
    'sf': '140357727781376-2'
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
    'sf': '140357727781376-3'
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
    'sf': '140357727781376-3'
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
    'sf': '140357727781376-3'
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
    'sf': '140357727781376-3'
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
    'sf': '140357727781376-5'
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
    'sf': '140357727781376-5'
  },
];
