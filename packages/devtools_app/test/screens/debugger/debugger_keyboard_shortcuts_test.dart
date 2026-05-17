// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/screens/debugger/debugger_model.dart';
import 'package:devtools_app/src/screens/debugger/debugger_screen.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_test/devtools_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:vm_service/vm_service.dart';

// Regression tests for the debugger keyboard shortcuts added for
// https://github.com/flutter/devtools/issues/3867. Each Action's `isEnabled`
// and `invoke` is exercised directly so the gating logic does not depend on
// pumping the full debugger widget tree.

void main() {
  late FakeServiceConnectionManager fakeServiceConnection;
  late MockDebuggerController debuggerController;

  StackFrameAndSourcePosition makeFrame(int index) {
    return StackFrameAndSourcePosition(
      Frame(index: index, kind: FrameKind.kRegular),
    );
  }

  setUp(() {
    fakeServiceConnection = FakeServiceConnectionManager();
    mockConnectedApp(fakeServiceConnection.serviceManager.connectedApp!);
    setGlobal(ServiceConnectionManager, fakeServiceConnection);
    setGlobal(IdeTheme, IdeTheme());
    setGlobal(NotificationService, NotificationService());

    debuggerController = createMockDebuggerControllerWithDefaults();
    when(debuggerController.isSystemIsolate).thenReturn(false);
    when(debuggerController.resuming).thenReturn(ValueNotifier<bool>(false));
    when(debuggerController.stackFramesWithLocation).thenReturn(
      ValueNotifier<List<StackFrameAndSourcePosition>>(
        <StackFrameAndSourcePosition>[],
      ),
    );
    when(
      debuggerController.selectedStackFrame,
    ).thenReturn(ValueNotifier<StackFrameAndSourcePosition?>(null));
  });

  group('PauseResumeAction', () {
    test('calls pause when not paused', () {
      fakeServiceConnection.serviceManager.isMainIsolatePaused = false;
      when(debuggerController.pause()).thenAnswer((_) async => Success());

      final action = PauseResumeAction();
      final intent = PauseResumeIntent(debuggerController);
      expect(action.isEnabled(intent), isTrue);
      action.invoke(intent);

      verify(debuggerController.pause()).called(1);
      verifyNever(debuggerController.resume());
    });

    test('calls resume when paused', () {
      fakeServiceConnection.serviceManager.isMainIsolatePaused = true;
      when(debuggerController.resume()).thenAnswer((_) async => Success());

      final action = PauseResumeAction();
      final intent = PauseResumeIntent(debuggerController);
      expect(action.isEnabled(intent), isTrue);
      action.invoke(intent);

      verify(debuggerController.resume()).called(1);
      verifyNever(debuggerController.pause());
    });

    test('isEnabled is false on a system isolate', () {
      when(debuggerController.isSystemIsolate).thenReturn(true);
      final action = PauseResumeAction();
      expect(action.isEnabled(PauseResumeIntent(debuggerController)), isFalse);
    });

    test('isEnabled is false when already resuming a paused isolate', () {
      fakeServiceConnection.serviceManager.isMainIsolatePaused = true;
      when(debuggerController.resuming).thenReturn(ValueNotifier<bool>(true));
      final action = PauseResumeAction();
      expect(action.isEnabled(PauseResumeIntent(debuggerController)), isFalse);
    });
  });

  group('NextStackFrameAction', () {
    test('isEnabled is false with fewer than 2 frames', () {
      when(debuggerController.stackFramesWithLocation).thenReturn(
        ValueNotifier<List<StackFrameAndSourcePosition>>(
          <StackFrameAndSourcePosition>[makeFrame(0)],
        ),
      );
      final action = NextStackFrameAction();
      expect(
        action.isEnabled(NextStackFrameIntent(debuggerController)),
        isFalse,
      );
    });

    test('selects the next frame after the currently selected one', () {
      final frame0 = makeFrame(0);
      final frame1 = makeFrame(1);
      final frame2 = makeFrame(2);
      when(debuggerController.stackFramesWithLocation).thenReturn(
        ValueNotifier<List<StackFrameAndSourcePosition>>(
          <StackFrameAndSourcePosition>[frame0, frame1, frame2],
        ),
      );
      when(
        debuggerController.selectedStackFrame,
      ).thenReturn(ValueNotifier<StackFrameAndSourcePosition?>(frame0));
      when(debuggerController.selectStackFrame(any)).thenAnswer((_) async {});

      NextStackFrameAction().invoke(NextStackFrameIntent(debuggerController));

      verify(debuggerController.selectStackFrame(frame1)).called(1);
    });

    test('wraps from the bottom frame back to the top', () {
      final frame0 = makeFrame(0);
      final frame1 = makeFrame(1);
      when(debuggerController.stackFramesWithLocation).thenReturn(
        ValueNotifier<List<StackFrameAndSourcePosition>>(
          <StackFrameAndSourcePosition>[frame0, frame1],
        ),
      );
      when(
        debuggerController.selectedStackFrame,
      ).thenReturn(ValueNotifier<StackFrameAndSourcePosition?>(frame1));
      when(debuggerController.selectStackFrame(any)).thenAnswer((_) async {});

      NextStackFrameAction().invoke(NextStackFrameIntent(debuggerController));

      verify(debuggerController.selectStackFrame(frame0)).called(1);
    });

    test('selects the first frame when nothing is selected', () {
      final frame0 = makeFrame(0);
      final frame1 = makeFrame(1);
      when(debuggerController.stackFramesWithLocation).thenReturn(
        ValueNotifier<List<StackFrameAndSourcePosition>>(
          <StackFrameAndSourcePosition>[frame0, frame1],
        ),
      );
      when(
        debuggerController.selectedStackFrame,
      ).thenReturn(ValueNotifier<StackFrameAndSourcePosition?>(null));
      when(debuggerController.selectStackFrame(any)).thenAnswer((_) async {});

      NextStackFrameAction().invoke(NextStackFrameIntent(debuggerController));

      verify(debuggerController.selectStackFrame(frame0)).called(1);
    });
  });

  group('Step actions', () {
    setUp(() {
      // Default: app paused with one stack frame on a non-system isolate.
      fakeServiceConnection.serviceManager.isMainIsolatePaused = true;
      when(debuggerController.stackFramesWithLocation).thenReturn(
        ValueNotifier<List<StackFrameAndSourcePosition>>(
          <StackFrameAndSourcePosition>[makeFrame(0)],
        ),
      );
    });

    test('StepOverAction calls stepOver when canStep', () {
      when(debuggerController.stepOver()).thenAnswer((_) async => Success());
      final action = StepOverAction();
      expect(action.isEnabled(StepOverIntent(debuggerController)), isTrue);
      action.invoke(StepOverIntent(debuggerController));
      verify(debuggerController.stepOver()).called(1);
    });

    test('StepInAction calls stepIn when canStep', () {
      when(debuggerController.stepIn()).thenAnswer((_) async => Success());
      final action = StepInAction();
      expect(action.isEnabled(StepInIntent(debuggerController)), isTrue);
      action.invoke(StepInIntent(debuggerController));
      verify(debuggerController.stepIn()).called(1);
    });

    test('StepOutAction calls stepOut when canStep', () {
      when(debuggerController.stepOut()).thenAnswer((_) async => Success());
      final action = StepOutAction();
      expect(action.isEnabled(StepOutIntent(debuggerController)), isTrue);
      action.invoke(StepOutIntent(debuggerController));
      verify(debuggerController.stepOut()).called(1);
    });

    test('step actions are disabled when the isolate is not paused', () {
      fakeServiceConnection.serviceManager.isMainIsolatePaused = false;
      expect(
        StepOverAction().isEnabled(StepOverIntent(debuggerController)),
        isFalse,
      );
      expect(
        StepInAction().isEnabled(StepInIntent(debuggerController)),
        isFalse,
      );
      expect(
        StepOutAction().isEnabled(StepOutIntent(debuggerController)),
        isFalse,
      );
    });

    test('step actions are disabled while a resume is already in flight', () {
      when(debuggerController.resuming).thenReturn(ValueNotifier<bool>(true));
      expect(
        StepOverAction().isEnabled(StepOverIntent(debuggerController)),
        isFalse,
      );
    });

    test('step actions are disabled when no stack frames are available', () {
      when(debuggerController.stackFramesWithLocation).thenReturn(
        ValueNotifier<List<StackFrameAndSourcePosition>>(
          <StackFrameAndSourcePosition>[],
        ),
      );
      expect(
        StepOverAction().isEnabled(StepOverIntent(debuggerController)),
        isFalse,
      );
    });

    test('step actions are disabled on a system isolate', () {
      when(debuggerController.isSystemIsolate).thenReturn(true);
      expect(
        StepOverAction().isEnabled(StepOverIntent(debuggerController)),
        isFalse,
      );
    });
  });
}
