// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/src/primitives/utils.dart';
import 'package:devtools_app/src/screens/profiler/cpu_profile_model.dart';

final Map<String, dynamic> goldenCpuProfileDataJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'sampleCount': 8,
  'stackDepth': 128,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3000,
  'stackFrames': goldenCpuProfileStackFrames,
  'traceEvents': goldenCpuProfileTraceEvents,
};

final Map<String, dynamic> emptyCpuProfileDataJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'sampleCount': 0,
  'stackDepth': 128,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 0,
  'stackFrames': {},
  'traceEvents': [],
};

final Map<String, dynamic> cpuProfileDataWithUserTagsJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'sampleCount': 5,
  'stackDepth': 128,
  'timeOriginMicros': 0,
  'timeExtentMicros': 250,
  'stackFrames': {
    '140357727781376-1': {
      'category': 'Dart',
      'name': 'Frame1',
      'parent': 'cpuProfileRoot',
      'resolvedUrl': '',
      'packageUri': '',
    },
    '140357727781376-2': {
      'category': 'Dart',
      'name': 'Frame2',
      'parent': '140357727781376-1',
      'resolvedUrl':
          'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/compact_hash.dart',
    },
    '140357727781376-3': {
      'category': 'Dart',
      'name': 'Frame3',
      'parent': '140357727781376-2',
      'resolvedUrl': '',
      'packageUri': '',
    },
    '140357727781376-4': {
      'category': 'Dart',
      'name': 'Frame4',
      'parent': '140357727781376-2',
      'resolvedUrl': '',
      'packageUri': '',
    },
    '140357727781376-5': {
      'category': 'Dart',
      'name': 'Frame5',
      'parent': '140357727781376-1',
      'resolvedUrl':
          'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/compact_hash.dart',
    },
    '140357727781376-6': {
      'category': 'Dart',
      'name': 'Frame6',
      'parent': '140357727781376-5',
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/rendering/custom_layout.dart',
    },
  },
  'traceEvents': [
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 50,
      'cat': 'Dart',
      'args': {
        'userTag': 'userTagA',
      },
      'sf': '140357727781376-3'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 100,
      'cat': 'Dart',
      'args': {
        'userTag': 'userTagB',
      },
      'sf': '140357727781376-4'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 150,
      'cat': 'Dart',
      'args': {
        'userTag': 'userTagA',
      },
      'sf': '140357727781376-5'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 200,
      'cat': 'Dart',
      'args': {
        'userTag': 'userTagC',
      },
      'sf': '140357727781376-5'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 250,
      'cat': 'Dart',
      'args': {
        'userTag': 'userTagC',
      },
      'sf': '140357727781376-6'
    },
  ],
};

const goldenCpuProfileString = '''
  all - children: 2 - excl: 0 - incl: 8
    thread_start - children: 1 - excl: 0 - incl: 2
      _pthread_start - children: 1 - excl: 0 - incl: 2
        _drawFrame - children: 2 - excl: 0 - incl: 2
          _WidgetsFlutterBinding.draw - children: 1 - excl: 0 - incl: 1
            RendererBinding.drawFrame - children: 0 - excl: 1 - incl: 1
          _RenderProxyBox.paint - children: 1 - excl: 0 - incl: 1
            PaintingContext.paintChild - children: 1 - excl: 0 - incl: 1
              _SyncBlock.finish - children: 0 - excl: 1 - incl: 1
    [Truncated] - children: 2 - excl: 0 - incl: 6
      RenderObject._getSemanticsForParent.<closure> - children: 1 - excl: 0 - incl: 1
        RenderObject._getSemanticsForParent - children: 0 - excl: 1 - incl: 1
      RenderPhysicalModel.paint - children: 1 - excl: 0 - incl: 5
        RenderCustomMultiChildLayoutBox.paint - children: 1 - excl: 0 - incl: 5
          _RenderCustomMultiChildLayoutBox.defaultPaint - children: 2 - excl: 3 - incl: 5
            RenderObject._paintWithContext - children: 0 - excl: 1 - incl: 1
            RenderStack.paintStack - children: 1 - excl: 0 - incl: 1
              Gesture._invokeFrameCallback - children: 0 - excl: 1 - incl: 1
''';

final Map<String, dynamic> cpuProfileResponseJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 50,
  'stackDepth': 128,
  'sampleCount': 8,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3000,
  'stackFrames': goldenCpuProfileStackFrames,
  'traceEvents': goldenCpuProfileTraceEvents,
};

final Map<String, dynamic> cpuProfileResponseEmptyJson = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 0,
  'stackDepth': 128,
  'sampleCount': 0,
  'timeSpan': 0.0,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 0,
  'stackFrames': {},
  'traceEvents': [],
};

const String goldenSamplesIsolate = '140357727781376';
final Map<String, dynamic> goldenCpuSamplesJson = {
  'type': 'CpuSamples',
  'samplePeriod': 50,
  'maxStackDepth': 128,
  'sampleCount': 8,
  'timeSpan': -1,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3000,
  'pid': 77616,
  'functions': [
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl': '',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'thread_start',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl': '',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '_pthread_start',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/compact_hash.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '_drawFrame',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '_WidgetsFlutterBinding.draw',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/rendering/binding.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RendererBinding.drawFrame',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/list.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '_RenderProxyBox.paint',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false,
        'location': {
          'type': 'SourceLocation',
          'script': null,
          'tokenPos': -1,
          'line': 123321
        }
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/painting/context.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'PaintingContext.paintChild',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl': '',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '_SyncBlock.finish',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl': '',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '[Truncated]',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RenderObject._getSemanticsForParent.<closure>',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RenderObject._getSemanticsForParent',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/rendering/proxy_box.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RenderPhysicalModel.paint',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/rendering/custom_layout.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RenderCustomMultiChildLayoutBox.paint',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/hash.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': '_RenderCustomMultiChildLayoutBox.defaultPaint',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RenderObject._paintWithContext',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl':
          'path/to/flutter/packages/flutter/lib/src/rendering/stack.dart',
      'function': {
        'type': '@Function',
        'id': '',
        'name': 'RenderStack.paintStack',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    },
    {
      'kind': 'Native',
      'inclusiveTicks': 0,
      'exclusiveTicks': 0,
      'resolvedUrl': '',
      'function': {
        'type': '@Function',
        'id': '',
        'name':
            '_WidgetsFlutterBinding&BindingBase&Gesture._invokeFrameCallback',
        'owner': null,
        'static': false,
        'const': false,
        'implicit': false,
        'abstract': false
      }
    }
  ],
  'samples': [
    {
      'tid': 42247,
      'timestamp': 47377796685,
      'stack': [4, 3, 2, 1, 0],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377797975,
      'stack': [7, 6, 5, 2, 1, 0],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377799063,
      'stack': [10, 9, 8],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377800363,
      'stack': [13, 12, 11, 8],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377800463,
      'stack': [13, 12, 11, 8],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377800563,
      'stack': [13, 12, 11, 8],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377800663,
      'stack': [14, 13, 12, 11, 8],
      'truncated': true
    },
    {
      'tid': 42247,
      'timestamp': 47377800763,
      'stack': [16, 15, 13, 12, 11, 8],
      'truncated': true
    }
  ]
};

final Map<String, String> goldenResolvedUriMap = {
  'path/to/flutter/packages/flutter/lib/src/rendering/proxy_box.dart':
      'package:flutter/lib/src/rendering/proxy_box.dart',
  'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/compact_hash.dart':
      'dart:vm/compact_hash.dart',
  'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/hash.dart':
      'dart:vm/hash.dart',
  'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/list.dart':
      'dart:vm/list.dart',
  'path/to/flutter/packages/flutter/lib/src/rendering/custom_layout.dart':
      'package:flutter/rendering/custom_layout.dart',
  'path/to/flutter/packages/flutter/lib/src/rendering/object.dart':
      'package:flutter/rendering/object.dart',
  'path/to/flutter/packages/flutter/lib/src/rendering/stack.dart':
      'package:flutter/rendering/stack.dart',
  'path/to/flutter/packages/flutter/lib/src/painting/context.dart':
      'package:flutter/painting/context.dart',
  'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart':
      'package:flutter/widgets/binding.dart',
};

final Map<String, dynamic> goldenCpuProfileStackFrames =
    Map.from(subProfileStackFrames)
      ..addAll({
        '140357727781376-12': {
          'category': 'Dart',
          'name': 'RenderPhysicalModel.paint',
          'parent': '140357727781376-9',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/proxy_box.dart',
          'packageUri': 'package:flutter/lib/src/rendering/proxy_box.dart',
          'sourceLine': null,
        },
        '140357727781376-13': {
          'category': 'Dart',
          'name': 'RenderCustomMultiChildLayoutBox.paint',
          'parent': '140357727781376-12',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/custom_layout.dart',
          'packageUri': 'package:flutter/rendering/custom_layout.dart',
          'sourceLine': null,
        },
        '140357727781376-14': {
          'category': 'Dart',
          'name': '_RenderCustomMultiChildLayoutBox.defaultPaint',
          'parent': '140357727781376-13',
          'resolvedUrl':
              'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/hash.dart',
          'packageUri': 'dart:vm/hash.dart',
          'sourceLine': null,
        },
        '140357727781376-15': {
          'category': 'Dart',
          'name': 'RenderObject._paintWithContext',
          'parent': '140357727781376-14',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
          'packageUri': 'package:flutter/rendering/object.dart',
          'sourceLine': null,
        },
        '140357727781376-16': {
          'category': 'Dart',
          'name': 'RenderStack.paintStack',
          'parent': '140357727781376-14',
          'resolvedUrl':
              'path/to/flutter/packages/flutter/lib/src/rendering/stack.dart',
          'packageUri': 'package:flutter/rendering/stack.dart',
          'sourceLine': null,
        },
        '140357727781376-17': {
          'category': 'Dart',
          'name':
              '_WidgetsFlutterBinding&BindingBase&Gesture._invokeFrameCallback',
          'parent': '140357727781376-16',
          'resolvedUrl': '',
          'packageUri': '',
          'sourceLine': null,
        }
      });

final subProfileStackFrames = {
  '140357727781376-1': {
    'category': 'Dart',
    'name': 'thread_start',
    'parent': 'cpuProfileRoot',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-2': {
    'category': 'Dart',
    'name': '_pthread_start',
    'parent': '140357727781376-1',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-3': {
    'category': 'Dart',
    'name': '_drawFrame',
    'parent': '140357727781376-2',
    'resolvedUrl':
        'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/compact_hash.dart',
    'packageUri': 'dart:vm/compact_hash.dart',
    'sourceLine': null,
  },
  '140357727781376-4': {
    'category': 'Dart',
    'name': '_WidgetsFlutterBinding.draw',
    'parent': '140357727781376-3',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
    'packageUri':
        'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
    'sourceLine': null,
  },
  '140357727781376-5': {
    'category': 'Dart',
    'name': 'RendererBinding.drawFrame',
    'parent': '140357727781376-4',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/binding.dart',
    'packageUri':
        'path/to/flutter/packages/flutter/lib/src/rendering/binding.dart',
    'sourceLine': null,
  },
  '140357727781376-6': {
    'category': 'Dart',
    'name': '_RenderProxyBox.paint',
    'parent': '140357727781376-3',
    'resolvedUrl': 'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/list.dart',
    'packageUri': 'dart:vm/list.dart',
    'sourceLine': 123321,
  },
  '140357727781376-7': {
    'category': 'Dart',
    'name': 'PaintingContext.paintChild',
    'parent': '140357727781376-6',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/painting/context.dart',
    'packageUri': 'package:flutter/painting/context.dart',
    'sourceLine': null,
  },
  '140357727781376-8': {
    'category': 'Dart',
    'name': '_SyncBlock.finish',
    'parent': '140357727781376-7',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-9': {
    'category': 'Dart',
    'name': '[Truncated]',
    'parent': 'cpuProfileRoot',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-10': {
    'category': 'Dart',
    'name': 'RenderObject._getSemanticsForParent.<closure>',
    'parent': '140357727781376-9',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'packageUri':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'sourceLine': null,
  },
  '140357727781376-11': {
    'category': 'Dart',
    'name': 'RenderObject._getSemanticsForParent',
    'parent': '140357727781376-10',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'packageUri':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'sourceLine': null,
  },
};

final filteredStackFrames = {
  '140357727781376-1': {
    'category': 'Dart',
    'name': 'thread_start',
    'parent': 'cpuProfileRoot',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-2': {
    'category': 'Dart',
    'name': '_pthread_start',
    'parent': '140357727781376-1',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-4': {
    'category': 'Dart',
    'name': '_WidgetsFlutterBinding.draw',
    'parent': '140357727781376-2',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
    'packageUri':
        'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
    'sourceLine': null,
  },
  '140357727781376-5': {
    'category': 'Dart',
    'name': 'RendererBinding.drawFrame',
    'parent': '140357727781376-4',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/binding.dart',
    'packageUri':
        'path/to/flutter/packages/flutter/lib/src/rendering/binding.dart',
    'sourceLine': null,
  },
  '140357727781376-7': {
    'category': 'Dart',
    'name': 'PaintingContext.paintChild',
    'parent': '140357727781376-2',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/painting/context.dart',
    'packageUri': 'package:flutter/painting/context.dart',
    'sourceLine': null,
  },
  '140357727781376-8': {
    'category': 'Dart',
    'name': '_SyncBlock.finish',
    'parent': '140357727781376-7',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-9': {
    'category': 'Dart',
    'name': '[Truncated]',
    'parent': 'cpuProfileRoot',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  },
  '140357727781376-10': {
    'category': 'Dart',
    'name': 'RenderObject._getSemanticsForParent.<closure>',
    'parent': '140357727781376-9',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'packageUri':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'sourceLine': null,
  },
  '140357727781376-11': {
    'category': 'Dart',
    'name': 'RenderObject._getSemanticsForParent',
    'parent': '140357727781376-10',
    'resolvedUrl':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'packageUri':
        'file:///path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'sourceLine': null,
  },
  '140357727781376-12': {
    'category': 'Dart',
    'name': 'RenderPhysicalModel.paint',
    'parent': '140357727781376-9',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/proxy_box.dart',
    'packageUri': 'package:flutter/lib/src/rendering/proxy_box.dart',
    'sourceLine': null,
  },
  '140357727781376-13': {
    'category': 'Dart',
    'name': 'RenderCustomMultiChildLayoutBox.paint',
    'parent': '140357727781376-12',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/custom_layout.dart',
    'packageUri': 'package:flutter/rendering/custom_layout.dart',
    'sourceLine': null,
  },
  '140357727781376-15': {
    'category': 'Dart',
    'name': 'RenderObject._paintWithContext',
    'parent': '140357727781376-13',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/object.dart',
    'packageUri': 'package:flutter/rendering/object.dart',
    'sourceLine': null,
  },
  '140357727781376-16': {
    'category': 'Dart',
    'name': 'RenderStack.paintStack',
    'parent': '140357727781376-13',
    'resolvedUrl':
        'path/to/flutter/packages/flutter/lib/src/rendering/stack.dart',
    'packageUri': 'package:flutter/rendering/stack.dart',
    'sourceLine': null,
  },
  '140357727781376-17': {
    'category': 'Dart',
    'name': '_WidgetsFlutterBinding&BindingBase&Gesture._invokeFrameCallback',
    'parent': '140357727781376-16',
    'resolvedUrl': '',
    'packageUri': '',
    'sourceLine': null,
  }
};

final filteredCpuSampleTraceEvents = [
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377796685,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-5'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377797975,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-8'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377799063,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-11'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800363,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-13'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800463,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-13'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800563,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-13'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800663,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-15'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377800763,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-17'
  }
];

final List<Map<String, dynamic>> goldenCpuProfileTraceEvents =
    List.from(subProfileTraceEvents)
      ..addAll([
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800363,
          'cat': 'Dart',
          'args': <String, dynamic>{},
          'sf': '140357727781376-14'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800463,
          'cat': 'Dart',
          'args': <String, dynamic>{},
          'sf': '140357727781376-14'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800563,
          'cat': 'Dart',
          'args': <String, dynamic>{},
          'sf': '140357727781376-14'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800663,
          'cat': 'Dart',
          'args': <String, dynamic>{},
          'sf': '140357727781376-15'
        },
        {
          'ph': 'P',
          'name': '',
          'pid': 77616,
          'tid': 42247,
          'ts': 47377800763,
          'cat': 'Dart',
          'args': <String, dynamic>{},
          'sf': '140357727781376-17'
        }
      ]);

final subProfileTraceEvents = [
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377796685,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-5'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377797975,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-8'
  },
  {
    'ph': 'P',
    'name': '',
    'pid': 77616,
    'tid': 42247,
    'ts': 47377799063,
    'cat': 'Dart',
    'args': <String, dynamic>{},
    'sf': '140357727781376-11'
  },
];

final responseWithMissingLeafFrame = {
  'type': '_CpuProfileTimeline',
  'samplePeriod': 1000,
  'stackDepth': 128,
  'sampleCount': 3,
  'timeSpan': 0.003678,
  'timeOriginMicros': 47377796685,
  'timeExtentMicros': 3678,
  'stackFrames': {
    // Missing stack frame 140357727781376-0
    '140357727781376-1': {
      'category': 'Dart',
      'name': 'thread_start',
      'parent': 'cpuProfileRoot',
      'resolvedUrl': '',
      'processerdUrl': '',
    },
    '140357727781376-2': {
      'category': 'Dart',
      'name': '_pthread_start',
      'parent': '140357727781376-1',
      'resolvedUrl': '',
      'packageUri': '',
    },
    '140357727781376-3': {
      'category': 'Dart',
      'name': '_drawFrame',
      'parent': '140357727781376-2',
      'resolvedUrl':
          'org-dartlang-sdk:///third_party/dart/sdk/lib/vm/hash.dart',
    },
    '140357727781376-4': {
      'category': 'Dart',
      'name': '_WidgetsFlutterBinding&BindingBase',
      'parent': '140357727781376-3',
      'resolvedUrl':
          'file:///path/to/flutter/packages/flutter/lib/src/scheduler/binding.dart',
    },
  },
  'traceEvents': [
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 47377796685,
      'cat': 'Dart',
      'args': <String, dynamic>{},
      'sf': '140357727781376-0'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 47377797975,
      'cat': 'Dart',
      'args': <String, dynamic>{},
      'sf': '140357727781376-2'
    },
    {
      'ph': 'P',
      'name': '',
      'pid': 77616,
      'tid': 42247,
      'ts': 47377799063,
      'cat': 'Dart',
      'args': <String, dynamic>{},
      'sf': '140357727781376-4'
    },
  ]
};

final CpuProfileMetaData profileMetaData = CpuProfileMetaData(
  sampleCount: 10,
  samplePeriod: 50,
  stackDepth: 128,
  time: TimeRange()
    ..start = const Duration()
    ..end = const Duration(microseconds: 100),
);

final CpuStackFrame stackFrameA = CpuStackFrame(
  id: 'id_0',
  name: 'A',
  verboseName: 'A',
  category: 'Dart',
  rawUrl: '',
  packageUri: '',
  sourceLine: null,
  parentId: CpuProfileData.rootId,
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 0;

final CpuStackFrame stackFrameB = CpuStackFrame(
  id: 'id_1',
  name: 'B',
  verboseName: 'B',
  category: 'Dart',
  rawUrl: 'org-dartlang-sdk:///third_party/dart/sdk/lib/async/zone.dart',
  packageUri: 'dart:async/zone.dart',
  sourceLine: 2222,
  parentId: 'id_0',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 0;

final CpuStackFrame stackFrameC = CpuStackFrame(
  id: 'id_2',
  name: 'C',
  verboseName: 'C',
  category: 'Dart',
  rawUrl:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  packageUri: 'package:flutter/widgets/binding.dart',
  sourceLine: 3333,
  parentId: 'id_1',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 2;
final CpuStackFrame stackFrameD = CpuStackFrame(
  id: 'id_3',
  name: 'D',
  verboseName: 'D',
  category: 'Dart',
  rawUrl: 'flutter::AnimatorBeginFrame',
  packageUri: 'processedflutter::AnimatorBeginFrame',
  sourceLine: null,
  parentId: 'id_1',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 2;

final CpuStackFrame stackFrameE = CpuStackFrame(
  id: 'id_4',
  name: 'E',
  verboseName: 'E',
  category: 'Dart',
  rawUrl: 'url',
  packageUri: 'packageUri',
  sourceLine: null,
  parentId: 'id_3',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 1;
final CpuStackFrame stackFrameF = CpuStackFrame(
  id: 'id_5',
  name: 'F',
  verboseName: 'F',
  category: 'Dart',
  rawUrl: 'url',
  packageUri: 'processsedUrl',
  sourceLine: null,
  parentId: 'id_4',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 0;

final CpuStackFrame stackFrameF2 = CpuStackFrame(
  id: 'id_6',
  name: 'F',
  verboseName: 'F',
  category: 'Dart',
  rawUrl: 'url',
  packageUri: 'packageUri',
  sourceLine: null,
  parentId: 'id_3',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 3;

final CpuStackFrame stackFrameC2 = CpuStackFrame(
  id: 'id_7',
  name: 'C',
  verboseName: 'C',
  category: 'Dart',
  rawUrl:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  packageUri: 'package:flutter/widgets/binding.dart',
  sourceLine: 3333,
  parentId: 'id_5',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 1;

final CpuStackFrame stackFrameC3 = CpuStackFrame(
  id: 'id_8',
  name: 'C',
  verboseName: 'C',
  category: 'Dart',
  rawUrl:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  packageUri: 'package:flutter/widgets/binding.dart',
  sourceLine: 3333,
  parentId: 'id_6',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 1;

final CpuStackFrame stackFrameC4 = CpuStackFrame(
  id: 'id_8',
  name: 'C',
  verboseName: 'C',
  category: 'Dart',
  rawUrl:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  packageUri:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  sourceLine: 47,
  parentId: 'id_6',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 1;

final CpuStackFrame stackFrameG = CpuStackFrame(
  id: 'id_9',
  name: 'G',
  verboseName: 'G',
  category: 'Dart',
  rawUrl:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  packageUri:
      'file:///path/to/flutter/packages/flutter/lib/src/widgets/binding.dart',
  sourceLine: null,
  parentId: 'id_0',
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 1;

final CpuStackFrame testStackFrame = stackFrameA
  ..addChild(
    stackFrameB
      ..addChild(stackFrameC)
      ..addChild(
        stackFrameD
          ..addChild(stackFrameE..addChild(stackFrameF..addChild(stackFrameC2)))
          ..addChild(stackFrameF2..addChild(stackFrameC3)),
      ),
  );

const String testStackFrameStringGolden = '''
  A - children: 1 - excl: 0 - incl: 10
    B - children: 2 - excl: 0 - incl: 10
      C - children: 0 - excl: 2 - incl: 2
      D - children: 2 - excl: 2 - incl: 8
        E - children: 1 - excl: 1 - incl: 2
          F - children: 1 - excl: 0 - incl: 1
            C - children: 0 - excl: 1 - incl: 1
        F - children: 1 - excl: 3 - incl: 4
          C - children: 0 - excl: 1 - incl: 1
''';

const String bottomUpPreMergeGolden = '''
  C - children: 1 - excl: 2 - incl: 2
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2

  D - children: 1 - excl: 2 - incl: 2
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2

  E - children: 1 - excl: 1 - incl: 1
    D - children: 1 - excl: 1 - incl: 1
      B - children: 1 - excl: 1 - incl: 1
        A - children: 0 - excl: 1 - incl: 1

  C - children: 1 - excl: 1 - incl: 1
    F - children: 1 - excl: 1 - incl: 1
      E - children: 1 - excl: 1 - incl: 1
        D - children: 1 - excl: 1 - incl: 1
          B - children: 1 - excl: 1 - incl: 1
            A - children: 0 - excl: 1 - incl: 1

  F - children: 1 - excl: 3 - incl: 3
    D - children: 1 - excl: 3 - incl: 3
      B - children: 1 - excl: 3 - incl: 3
        A - children: 0 - excl: 3 - incl: 3

  C - children: 1 - excl: 1 - incl: 1
    F - children: 1 - excl: 1 - incl: 1
      D - children: 1 - excl: 1 - incl: 1
        B - children: 1 - excl: 1 - incl: 1
          A - children: 0 - excl: 1 - incl: 1

''';

const String bottomUpGolden = '''
  C - children: 2 - excl: 4 - incl: 4
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2
    F - children: 2 - excl: 2 - incl: 2
      E - children: 1 - excl: 1 - incl: 1
        D - children: 1 - excl: 1 - incl: 1
          B - children: 1 - excl: 1 - incl: 1
            A - children: 0 - excl: 1 - incl: 1
      D - children: 1 - excl: 1 - incl: 1
        B - children: 1 - excl: 1 - incl: 1
          A - children: 0 - excl: 1 - incl: 1

  D - children: 1 - excl: 2 - incl: 2
    B - children: 1 - excl: 2 - incl: 2
      A - children: 0 - excl: 2 - incl: 2

  E - children: 1 - excl: 1 - incl: 1
    D - children: 1 - excl: 1 - incl: 1
      B - children: 1 - excl: 1 - incl: 1
        A - children: 0 - excl: 1 - incl: 1

  F - children: 1 - excl: 3 - incl: 3
    D - children: 1 - excl: 3 - incl: 3
      B - children: 1 - excl: 3 - incl: 3
        A - children: 0 - excl: 3 - incl: 3

''';

final CpuProfileMetaData zeroProfileMetaData = CpuProfileMetaData(
  sampleCount: 0,
  samplePeriod: 50,
  stackDepth: 128,
  time: TimeRange()
    ..start = const Duration()
    ..end = const Duration(microseconds: 100),
);

final CpuStackFrame zeroStackFrame = CpuStackFrame(
  id: 'id_0',
  name: 'A',
  verboseName: 'A',
  category: 'Dart',
  rawUrl: '',
  packageUri: '',
  sourceLine: null,
  parentId: CpuProfileData.rootId,
  profileMetaData: zeroProfileMetaData,
)..exclusiveSampleCount = 0;

final flutterEngineStackFrame = CpuStackFrame(
  id: 'id-100',
  name: 'flutter::AnimatorBeginFrame',
  verboseName: 'flutter::AnimatorBeginFrame',
  category: 'Dart',
  rawUrl: '',
  packageUri: '',
  sourceLine: null,
  parentId: CpuProfileData.rootId,
  profileMetaData: profileMetaData,
)..exclusiveSampleCount = 1;
