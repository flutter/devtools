// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:test/test.dart';

import '../support/cli_test_driver.dart';
import 'integration.dart';
import 'util.dart';

void debuggingTests() {
  CliAppFixture appFixture;
  BrowserTabInstance tabInstance;

  setUp(() async {
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance?.close();
    await appFixture?.teardown();
  });

  test('lists scripts', () async {
    appFixture = await CliAppFixture.create('test/fixtures/debugging_app.dart');

    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = DebuggingManager(tools);

    // TODO(dantup): This check can be removed on the next stable Dart release
    // since we'll only be running the tests where getScripts is supported.
    if (!(await debuggingManager.supportsScripts())) {
      print('=== VM does not support getScripts, skipping test ===');
      return;
    }

    // Allow some time for the scripts view to be populated, as it requires
    // some isolate events to fire that we have not already waited for.
    await waitFor(
      () async => (await debuggingManager.getScripts()).isNotEmpty,
      timeoutMessage: 'Scripts view was not populated',
    );
    final List<String> scripts = await debuggingManager.getScripts();
    expect(scripts, isNotEmpty);
    expect(scripts, anyElement(endsWith(appFixture.appScriptPath)));
  });

  test('breakpoints, variables, resume', () async {
    appFixture = await CliAppFixture.create('test/fixtures/debugging_app.dart');

    final String source = appFixture.scriptSource;
    final List<int> breakpointLines =
        CliAppFixture.parseBreakpointLines(source);

    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = DebuggingManager(tools);

    // clear and verify breakpoints
    List<String> breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isEmpty);

    // TODO(dantup): This check can be removed on the next stable Dart release
    // since we'll only be running the tests where getScripts is supported.
    if (!(await debuggingManager.supportsScripts())) {
      print(
          '=== VM does not support getScripts, required by addBreakpoint, skipping test ===');
      return;
    }

    await delay();

    // set and verify breakpoints
    for (int line in breakpointLines) {
      await debuggingManager.addBreakpoint(appFixture.appScriptPath, line);
    }

    breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isNotEmpty);

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');

    await delay();

    // verify location
    expect(
      await debuggingManager.getLocation(),
      endsWith('${appFixture.appScriptPath}:${breakpointLines.first}'),
    );

    // verify stack frame
    final List<String> frames = await debuggingManager.getCallStackFrames();
    expect(frames.length, greaterThan(2));
    expect(frames.sublist(0, 2), [
      'Cat.performAction:debugging_app.dart',
      'main.run.<anonymous closure>:debugging_app.dart',
    ]);

    // verify variables
    expect(
      await debuggingManager.getVariables(),
      unorderedEquals(['this:Cat', 'actionStr:catAction!']),
    );

    // resume
    await debuggingManager.clearBreakpoints();
    await debuggingManager.resume();

    await delay();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('stepping, async step, async frames', () async {
    appFixture =
        await CliAppFixture.create('test/fixtures/debugging_app_async.dart');

    final String source = appFixture.scriptSource;
    final int breakpointLine =
        CliAppFixture.parseBreakpointLines(source).single;
    final List<int> steppingLines = CliAppFixture.parseSteppingLines(source);

    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = DebuggingManager(tools);

    // clear and verify breakpoints
    List<String> breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isEmpty);

    // TODO(dantup): This check can be removed on the next stable Dart release
    // since we'll only be running the tests where getScripts is supported.
    if (!(await debuggingManager.supportsScripts())) {
      print(
          '=== VM does not support getScripts, required by addBreakpoint, skipping test ===');
      return;
    }

    await delay();

    // set and verify breakpoint
    await debuggingManager.addBreakpoint(
        appFixture.appScriptPath, breakpointLine);

    breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, hasLength(1));

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');

    await shortDelay();

    // verify location
    expect(
      await debuggingManager.getLocation(),
      endsWith('${appFixture.appScriptPath}:$breakpointLine'),
    );

    // test stepping
    for (int stepLine in steppingLines) {
      // step
      await debuggingManager.step();

      // wait for paused state
      await waitFor(() async => await debuggingManager.getState() == 'paused');

      await delay();

      // verify location
      expect(
        await debuggingManager.getLocation(),
        endsWith('${appFixture.appScriptPath}:$stepLine'),
      );
    }

    // verify an async stack frame
    final List<String> frames = await debuggingManager.getCallStackFrames();
    expect(frames.length, greaterThan(4));
    expect(frames.sublist(0, 4), [
      'performAction:debugging_app_async.dart',
      '<async break>',
      'main.run.<anonymous closure>:debugging_app_async.dart',
      '<async break>',
    ]);

    // resume
    await debuggingManager.clearBreakpoints();
    await debuggingManager.resume();

    await delay();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('break on exceptions', () async {
    appFixture = await CliAppFixture.create(
        'test/fixtures/debugging_app_exception.dart');

    final String source = appFixture.scriptSource;
    final int exceptionLine = CliAppFixture.parseExceptionLines(source).first;

    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = DebuggingManager(tools);

    // verify running state
    expect(await debuggingManager.getState(), 'running');

    // set break on exceptions mode
    await debuggingManager.setExceptionPauseMode('All');

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');

    await delay();

    // verify location
    expect(
      await debuggingManager.getLocation(),
      endsWith('${appFixture.appScriptPath}:$exceptionLine'),
    );

    // verify locals, including the exception object
    expect(await debuggingManager.getVariables(), [
      '<exception>:StateError',
      'foo:2',
    ]);

    // resume
    await debuggingManager.setExceptionPauseMode('Unhandled');
    await debuggingManager.resume();

    await delay();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('console output', () async {
    appFixture = await CliAppFixture.create(
        'test/fixtures/debugging_app_exception.dart');

    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = DebuggingManager(tools);

    // verify running state
    expect(await debuggingManager.getState(), 'running');

    // wait until there's console output
    await waitFor(
        () async => (await debuggingManager.getConsoleContents()).isNotEmpty);

    // verify the console contents
    expect(
      await debuggingManager.getConsoleContents(),
      contains('1\n'),
    );
  });

  test('pause', () async {
    appFixture = await CliAppFixture.create('test/fixtures/debugging_app.dart');

    final DevtoolsManager tools =
        DevtoolsManager(tabInstance, webdevFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final String currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final DebuggingManager debuggingManager = DebuggingManager(tools);

    // verify running state
    expect(await debuggingManager.getState(), 'running');

    // pause
    await debuggingManager.pause();

    // wait for paused state
    await waitFor(() async => await debuggingManager.getState() == 'paused');
    expect(await debuggingManager.getState(), 'paused');

    // resume
    await debuggingManager.resume();

    await delay();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });
}

class DebuggingManager {
  DebuggingManager(this.tools);

  final DevtoolsManager tools;

  Future<void> resume() async {
    await tools.tabInstance.send('debugger.resume');
  }

  Future<void> pause() async {
    await tools.tabInstance.send('debugger.pause');
  }

  Future<void> step() async {
    await tools.tabInstance.send('debugger.step');
  }

  Future<String> getLocation() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getLocation');
    return response.result as String;
  }

  Future<List<String>> getVariables() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getVariables');
    final List<dynamic> result = response.result as List;
    return result.cast<String>();
  }

  Future<String> getState() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getState');
    return response.result as String;
  }

  Future<String> getConsoleContents() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getConsoleContents');
    return response.result as String;
  }

  Future<void> clearBreakpoints() async {
    await tools.tabInstance.send('debugger.clearBreakpoints');
  }

  Future<void> addBreakpoint(String path, int line) async {
    await tools.tabInstance.send('debugger.addBreakpoint', [path, line]);
  }

  Future<void> setExceptionPauseMode(String mode) async {
    await tools.tabInstance.send('debugger.setExceptionPauseMode', mode);
  }

  Future<List<String>> getBreakpoints() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getBreakpoints');
    final List<dynamic> result = response.result as List;
    return result.cast<String>();
  }

  Future<List<String>> getScripts() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getScripts');
    final List<dynamic> result = response.result as List;
    return result.cast<String>();
  }

  Future<bool> supportsScripts() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.supportsScripts');
    return response.result as bool;
  }

  Future<List<String>> getCallStackFrames() async {
    final AppResponse response =
        await tools.tabInstance.send('debugger.getCallStackFrames');
    final List<dynamic> result = response.result as List;
    return result.cast<String>();
  }
}
