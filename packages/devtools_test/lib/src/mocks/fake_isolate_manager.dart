// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'mocks.dart';

class FakeIsolateManager extends Fake implements IsolateManager {
  @override
  ValueListenable<IsolateRef?> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate =
      ValueNotifier(IsolateRef.parse({'id': 'fake_isolate_id'}));

  @override
  ValueListenable<IsolateRef?> get mainIsolate => _mainIsolate;
  final _mainIsolate =
      ValueNotifier(IsolateRef.parse({'id': 'fake_main_isolate_id'}));

  @override
  ValueNotifier<List<IsolateRef>> get isolates {
    final value = _selectedIsolate.value;
    _isolates ??= ValueNotifier([if (value != null) value]);
    return _isolates!;
  }

  ValueNotifier<List<IsolateRef>>? _isolates;

  @override
  IsolateState isolateDebuggerState(IsolateRef? isolate) {
    final state = MockIsolateState();
    final mockIsolate = MockIsolate();
    when(mockIsolate.libraries).thenReturn([]);
    when(state.isolateNow).thenReturn(mockIsolate);
    return state;
  }
}
