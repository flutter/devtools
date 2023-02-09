// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:flutter/foundation.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

import 'generated.mocks.dart';

class FakeIsolateManager extends Fake implements IsolateManager {
  @override
  ValueListenable<IsolateRef?> get selectedIsolate => _selectedIsolate;
  final _selectedIsolate = ValueNotifier(
    IsolateRef.parse({
      'id': 'fake_isolate_id',
      'name': 'selected-isolate',
    }),
  );

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

  final _pausedState = ValueNotifier<bool>(false);

  @visibleForTesting
  void setMainIsolatePausedState(bool paused) {
    _pausedState.value = paused;
  }

  @override
  IsolateState? get mainIsolateState => isolateState(null);

  ValueNotifier<List<IsolateRef>>? _isolates;

  @override
  IsolateState isolateState(IsolateRef? isolate) {
    final state = MockIsolateState();
    final mockIsolate = MockIsolate();
    final rootLib = LibraryRef(id: '0', uri: 'pacakge:my_app/main.dart');
    when(mockIsolate.libraries).thenReturn(
      [
        rootLib,
        LibraryRef(id: '1', uri: 'dart:io'),
      ],
    );
    when(mockIsolate.rootLib).thenReturn(rootLib);
    when(state.isolateNow).thenReturn(mockIsolate);
    when(state.isPaused).thenReturn(_pausedState);
    when(state.isolate).thenAnswer((_) => Future.value(mockIsolate));
    return state;
  }
}
