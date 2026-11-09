// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

void main() {
  late FakeVmServiceWrapper fakeService;
  late BreakpointManager manager;
  late IsolateRef isolateRef;

  setUp(() async {
    final fakeServiceConnection = FakeServiceConnectionManager();
    fakeService =
        fakeServiceConnection.serviceManager.service! as FakeVmServiceWrapper;
    mockConnectedApp(fakeServiceConnection.serviceManager.connectedApp!);
    final scriptManager = MockScriptManager();
    when(
      scriptManager.retrieveAndSortScripts(any),
    ).thenAnswer((_) async => <ScriptRef>[]);
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(ScriptManager, scriptManager);

    manager = BreakpointManager();
    setGlobal(BreakpointManager, manager);
    await manager.initialize();
    isolateRef = fakeServiceConnection
        .serviceManager
        .isolateManager
        .selectedIsolate
        .value!;
  });

  tearDown(() {
    manager
      ..cancelStreamSubscriptions()
      ..cancelListeners();
  });

  Breakpoint createBreakpoint({required bool enabled}) => Breakpoint(
    breakpointNumber: 1,
    id: 'bp1',
    resolved: false,
    location: UnresolvedSourceLocation(
      scriptUri: 'package:test/script.dart',
      line: 10,
    ),
    enabled: enabled,
  );

  Future<void> emitBreakpointEvent(String kind, Breakpoint breakpoint) async {
    fakeService.emitDebugEvent(
      Event(kind: kind, isolate: isolateRef, breakpoint: breakpoint),
    );
    await pumpEventQueue();
  }

  test('updates the enabled state of a breakpoint when the VM reports it '
      'was updated', () async {
    await emitBreakpointEvent(
      EventKind.kBreakpointAdded,
      createBreakpoint(enabled: true),
    );
    expect(manager.breakpointsWithLocation.value.single.enabled, isTrue);

    var notified = false;
    manager.breakpointsWithLocation.addListener(() => notified = true);

    await emitBreakpointEvent(
      EventKind.kBreakpointUpdated,
      createBreakpoint(enabled: false),
    );

    expect(notified, isTrue);
    expect(manager.breakpointsWithLocation.value.single.enabled, isFalse);
  });
}
