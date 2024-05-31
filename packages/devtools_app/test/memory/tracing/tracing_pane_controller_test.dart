// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_data.dart';
import 'package:devtools_app/src/screens/memory/panes/tracing/tracing_pane_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vm_service/vm_service.dart';

// ignore: avoid_classes_with_only_static_members, ok for enum-like class
class _Tests {
  static final TracePaneController emptyConnected = TracePaneController(
    ControllerCreationMode.connected,
    rootPackage: '',
  );

  static final TracePaneController emptyOffline = TracePaneController(
    ControllerCreationMode.offlineData,
    rootPackage: '',
  );

  static final TracePaneController selection = TracePaneController(
    ControllerCreationMode.connected,
    stateForIsolate: {
      'isolate1': TracingIsolateState(
        isolate: IsolateRef(id: 'isolate1'),
        mode: ControllerCreationMode.connected,
      ),
      'isolate2': TracingIsolateState(
        isolate: IsolateRef(id: 'isolate2'),
        mode: ControllerCreationMode.connected,
      ),
    },
    rootPackage: 'root',
    selectedIsolateId: 'isolate1',
  );

  static final TracePaneController noSelection = TracePaneController(
    ControllerCreationMode.connected,
    stateForIsolate: {
      'isolate1': TracingIsolateState(
        isolate: IsolateRef(id: 'isolate1'),
        mode: ControllerCreationMode.connected,
      ),
      'isolate2': TracingIsolateState(
        isolate: IsolateRef(id: 'isolate2'),
        mode: ControllerCreationMode.connected,
      ),
    },
    rootPackage: 'root',
  );

  static final all = {
    'emptyConnected': emptyConnected,
    'emptyOffline': emptyOffline,
    'selection': selection,
    'noSelection': noSelection,
  };
}

void main() {
  test('$TracePaneController construction with wrong isolate fails', () {
    expect(
      () => TracePaneController(
        rootPackage: 'root',
        ControllerCreationMode.connected,
        stateForIsolate: {
          'isolate1': TracingIsolateState(
            isolate: IsolateRef(id: 'isolate1'),
            mode: ControllerCreationMode.connected,
          ),
          'isolate2': TracingIsolateState(
            isolate: IsolateRef(id: 'isolate2'),
            mode: ControllerCreationMode.connected,
          ),
        },
        selectedIsolateId: 'isolate3',
      ),
      throwsArgumentError,
    );
  });

  test('$TracePaneController construction', () {
    expect(_Tests.emptyConnected.mode, ControllerCreationMode.connected);
    expect(_Tests.emptyConnected.selection.value.isolate.id, null);
    expect(_Tests.emptyConnected.stateForIsolate.length, 0);

    expect(_Tests.emptyOffline.mode, ControllerCreationMode.offlineData);
    expect(_Tests.emptyOffline.selection.value.isolate.id, null);
    expect(_Tests.emptyOffline.stateForIsolate.length, 0);

    expect(_Tests.selection.mode, ControllerCreationMode.connected);
    expect(_Tests.selection.selection.value.isolate.id, 'isolate1');
    expect(_Tests.selection.stateForIsolate.length, 2);

    expect(_Tests.noSelection.mode, ControllerCreationMode.connected);
    expect(_Tests.noSelection.selection.value.isolate.id, null);
    expect(_Tests.noSelection.stateForIsolate.length, 2);
  });

  for (final t in _Tests.all.keys) {
    test(
      '$TracePaneController serializes and deserializes correctly, $t',
      () {
        final trace = _Tests.all[t]!;

        final json = trace.toJson();
        expect(
          json.keys.toSet(),
          equals(Json.values.map((e) => e.name).toSet()),
        );
        final fromJson = TracePaneController.fromJson(json);

        expect(fromJson.mode, ControllerCreationMode.offlineData);
        expect(
          fromJson.selection.value.isolate.id,
          trace.selection.value.isolate.id,
        );
        expect(
          fromJson.stateForIsolate.length,
          trace.stateForIsolate.length,
        );
      },
    );
  }
}
