// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_test_utils.dart';
import 'package:flutter_test/flutter_test.dart';

import 'integration.dart';

void debuggingTests() {
  late CliAppFixture appFixture;
  late BrowserTabInstance tabInstance;

  setUp(() async {
    tabInstance = await browserManager.createNewTab();
  });

  tearDown(() async {
    await tabInstance.close();
    await appFixture.teardown();
  });

  test('lists scripts', () async {
    appFixture = await CliAppFixture.create(
      'test/test_infra/fixtures/debugging_app.dart',
    );

    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final debuggingManager = DebuggingManager(tools);

    // Allow some time for the scripts view to be populated, as it requires
    // some isolate events to fire that we have not already waited for.
    await waitFor(
      () async => (await debuggingManager.getScripts()).isNotEmpty,
      timeoutMessage: 'Scripts view was not populated',
    );
    final scripts = await debuggingManager.getScripts();
    expect(scripts, isNotEmpty);
    expect(scripts, anyElement(endsWith(appFixture.appScriptPath)));
  });

  test('breakpoints, variables, resume', () async {
    appFixture = await CliAppFixture.create(
      'test/test_infra/fixtures/debugging_app.dart',
    );

    final source = appFixture.scriptSource;
    final breakpointLines = CliAppFixture.parseBreakpointLines(source);

    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final debuggingManager = DebuggingManager(tools);

    // clear and verify breakpoints
    List<String> breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isEmpty);

    await delay();

    // set and verify breakpoints
    for (final line in breakpointLines) {
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
    final frames = await debuggingManager.getCallStackFrames();
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
    appFixture = await CliAppFixture.create(
      'test/test_infra/fixtures/debugging_app_async.dart',
    );

    final source = appFixture.scriptSource;
    final breakpointLine = CliAppFixture.parseBreakpointLines(source).single;
    final steppingLines = CliAppFixture.parseSteppingLines(source);

    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final debuggingManager = DebuggingManager(tools);

    // clear and verify breakpoints
    List<String> breakpoints = await debuggingManager.getBreakpoints();
    expect(breakpoints, isEmpty);

    await delay();

    // set and verify breakpoint
    await debuggingManager.addBreakpoint(
      appFixture.appScriptPath,
      breakpointLine,
    );

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
    for (final stepLine in steppingLines) {
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
    final frames = await debuggingManager.getCallStackFrames();
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
      'test/test_infra/fixtures/debugging_app_exception.dart',
    );

    final source = appFixture.scriptSource;
    final exceptionLine = CliAppFixture.parseExceptionLines(source).first;

    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final debuggingManager = DebuggingManager(tools);

    // verify running state
    expect(await debuggingManager.getState(), 'running');

    // set break on exceptions mode
    await debuggingManager.setIsolatePauseMode('All');

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
    await debuggingManager.setIsolatePauseMode('Unhandled');
    await debuggingManager.resume();

    await delay();

    // verify state resumed
    expect(await debuggingManager.getState(), 'running');
  });

  test('console output', () async {
    appFixture = await CliAppFixture.create(
      'test/test_infra/fixtures/color_console_output_app.dart',
    );

    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final debuggingManager = DebuggingManager(tools);

    // This test app must start paused so we don't have race conditions where
    // we miss some console output that was emitted too early.
    await waitFor(() async => await debuggingManager.getState() == 'paused');
    await debuggingManager.resume();
    expect(await debuggingManager.getState(), 'running');

    // Wait until there is enough console output.
    await waitFor(
      () async =>
          (await debuggingManager.getConsoleContents())!.split('\n').length >=
          13,
    );
    // Verify the console contents.
    expect(
      await debuggingManager.getConsoleContents(),
      startsWith(
        'starting ansi color app\n'
        '<span style=\'background-color: rgb(0,0,0);color: rgb(255,255,255)\'>0 <span style=\'color: rgb(0,0,0)\'> </span>0 <span style=\'background-color: rgb(187,0,0);color: rgb(255,255,255)\'>1</span> <span style=\'color: rgb(187,0,0)\'> </span>1 <span style=\'background-color: rgb(0,187,0);color: rgb(255,255,255)\'>2</span> <span style=\'color: rgb(0,187,0)\'> </span>2 <span style=\'background-color: rgb(187,187,0);color: rgb(255,255,255)\'>3</span> <span style=\'color: rgb(187,187,0)\'> </span>3 <span style=\'background-color: rgb(0,0,187);color: rgb(255,255,255)\'>4</span> <span style=\'color: rgb(0,0,187)\'> </span>4 <span style=\'background-color: rgb(187,0,187);color: rgb(255,255,255)\'>5</span> <span style=\'color: rgb(187,0,187)\'> </span>5 <span style=\'background-color: rgb(0,187,187);color: rgb(255,255,255)\'>6</span> <span style=\'color: rgb(0,187,187)\'> </span>6 <span style=\'background-color: rgb(255,255,255);color: rgb(255,255,255)\'>7</span> <span style=\'color: rgb(255,255,255)\'> </span>7 \n'
        '<span style=\'background-color: rgb(85,85,85);color: rgb(255,255,255)\'>8 <span style=\'color: rgb(85,85,85)\'> </span>8 <span style=\'background-color: rgb(255,85,85);color: rgb(255,255,255)\'>9</span> <span style=\'color: rgb(255,85,85)\'> </span>9 <span style=\'background-color: rgb(0,255,0);color: rgb(255,255,255)\'>1</span>0 <span style=\'color: rgb(0,255,0)\'> </span>10 <span style=\'background-color: rgb(255,255,85);color: rgb(255,255,255)\'>1</span>1 <span style=\'color: rgb(255,255,85)\'> </span>11 <span style=\'background-color: rgb(85,85,255);color: rgb(255,255,255)\'>1</span>2 <span style=\'color: rgb(85,85,255)\'> </span>12 <span style=\'background-color: rgb(255,85,255);color: rgb(255,255,255)\'>1</span>3 <span style=\'color: rgb(255,85,255)\'> </span>13 <span style=\'background-color: rgb(85,255,255);color: rgb(255,255,255)\'>1</span>4 <span style=\'color: rgb(85,255,255)\'> </span>14 <span style=\'background-color: rgb(255,255,255);color: rgb(255,255,255)\'>1</span>5 <span style=\'color: rgb(255,255,255)\'> </span>15 \n'
        '\n'
        '<span style=\'background-color: rgb(0,0,0);color: rgb(255,255,255)\'> 16 <span style=\'color: rgb(0,0,0)\'> </span>16 <span style=\'background-color: rgb(0,0,175);color: rgb(255,255,255)\'> </span>19 <span style=\'color: rgb(0,0,175)\'> </span>19 \n'
        '<span style=\'background-color: rgb(0,175,0);color: rgb(255,255,255)\'> 34 <span style=\'color: rgb(0,175,0)\'> </span>34 <span style=\'background-color: rgb(0,175,175);color: rgb(255,255,255)\'> </span>37 <span style=\'color: rgb(0,175,175)\'> </span>37 \n'
        '\n'
        '<span style=\'background-color: rgb(175,0,0);color: rgb(255,255,255)\'> 124 <span style=\'color: rgb(175,0,0)\'> </span>124 <span style=\'background-color: rgb(175,0,175);color: rgb(255,255,255)\'> </span>127 <span style=\'color: rgb(175,0,175)\'> </span>127 \n'
        '<span style=\'background-color: rgb(175,175,0);color: rgb(255,255,255)\'> 142 <span style=\'color: rgb(175,175,0)\'> </span>142 <span style=\'background-color: rgb(175,175,175);color: rgb(255,255,255)\'> </span>145 <span style=\'color: rgb(175,175,175)\'> </span>145 \n'
        '\n'
        '<span style=\'background-color: rgb(8,8,8);color: rgb(255,255,255)\'> 232 <span style=\'color: rgb(8,8,8)\'> </span>232 <span style=\'background-color: rgb(18,18,18);color: rgb(255,255,255)\'> </span>233 <span style=\'color: rgb(18,18,18)\'> </span>233 <span style=\'background-color: rgb(28,28,28);color: rgb(255,255,255)\'> </span>234 <span style=\'color: rgb(28,28,28)\'> </span>234 <span style=\'background-color: rgb(38,38,38);color: rgb(255,255,255)\'> </span>235 <span style=\'color: rgb(38,38,38)\'> </span>235 <span style=\'background-color: rgb(48,48,48);color: rgb(255,255,255)\'> </span>236 <span style=\'color: rgb(48,48,48)\'> </span>236 <span style=\'background-color: rgb(58,58,58);color: rgb(255,255,255)\'> </span>237 <span style=\'color: rgb(58,58,58)\'> </span>237 <span style=\'background-color: rgb(68,68,68);color: rgb(255,255,255)\'> </span>238 <span style=\'color: rgb(68,68,68)\'> </span>238 <span style=\'background-color: rgb(78,78,78);color: rgb(255,255,255)\'> </span>239 <span style=\'color: rgb(78,78,78)\'> </span>239 \n'
        '<span style=\'background-color: rgb(88,88,88);color: rgb(255,255,255)\'> 240 <span style=\'color: rgb(88,88,88)\'> </span>240 <span style=\'background-color: rgb(98,98,98);color: rgb(255,255,255)\'> </span>241 <span style=\'color: rgb(98,98,98)\'> </span>241 <span style=\'background-color: rgb(108,108,108);color: rgb(255,255,255)\'> </span>242 <span style=\'color: rgb(108,108,108)\'> </span>242 <span style=\'background-color: rgb(118,118,118);color: rgb(255,255,255)\'> </span>243 <span style=\'color: rgb(118,118,118)\'> </span>243 <span style=\'background-color: rgb(128,128,128);color: rgb(255,255,255)\'> </span>244 <span style=\'color: rgb(128,128,128)\'> </span>244 <span style=\'background-color: rgb(138,138,138);color: rgb(255,255,255)\'> </span>245 <span style=\'color: rgb(138,138,138)\'> </span>245 <span style=\'background-color: rgb(148,148,148);color: rgb(255,255,255)\'> </span>246 <span style=\'color: rgb(148,148,148)\'> </span>246 <span style=\'background-color: rgb(158,158,158);color: rgb(255,255,255)\'> </span>247 <span style=\'color: rgb(158,158,158)\'> </span>247 \n'
        '<span style=\'background-color: rgb(168,168,168);color: rgb(255,255,255)\'> 248 <span style=\'color: rgb(168,168,168)\'> </span>248 <span style=\'background-color: rgb(178,178,178);color: rgb(255,255,255)\'> </span>249 <span style=\'color: rgb(178,178,178)\'> </span>249 <span style=\'background-color: rgb(188,188,188);color: rgb(255,255,255)\'> </span>250 <span style=\'color: rgb(188,188,188)\'> </span>250 <span style=\'background-color: rgb(198,198,198);color: rgb(255,255,255)\'> </span>251 <span style=\'color: rgb(198,198,198)\'> </span>251 <span style=\'background-color: rgb(208,208,208);color: rgb(255,255,255)\'> </span>252 <span style=\'color: rgb(208,208,208)\'> </span>252 <span style=\'background-color: rgb(218,218,218);color: rgb(255,255,255)\'> </span>253 <span style=\'color: rgb(218,218,218)\'> </span>253 <span style=\'background-color: rgb(228,228,228);color: rgb(255,255,255)\'> </span>254 <span style=\'color: rgb(228,228,228)\'> </span>254 <span style=\'background-color: rgb(238,238,238);color: rgb(255,255,255)\'> </span>255 <span style=\'color: rgb(238,238,238)\'> </span>255 \n',
      ),
    );
  });

  test('pause', () async {
    appFixture = await CliAppFixture.create(
      'test/test_infra/fixtures/debugging_app.dart',
    );

    final tools = DevtoolsManager(tabInstance, webBuildFixture.baseUri);
    await tools.start(appFixture);
    await tools.switchPage('debugger');

    final currentPageId = await tools.currentPageId();
    expect(currentPageId, 'debugger');

    final debuggingManager = DebuggingManager(tools);

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

  Future<String?> getLocation() async {
    final response = await tools.tabInstance.send('debugger.getLocation');
    return response.result as String?;
  }

  Future<List<String>> getVariables() async {
    final response = await tools.tabInstance.send('debugger.getVariables');
    final result = response.result as List<Object?>;
    return result.cast<String>();
  }

  Future<String?> getState() async {
    final response = await tools.tabInstance.send('debugger.getState');
    return response.result as String?;
  }

  Future<String?> getConsoleContents() async {
    final response =
        await tools.tabInstance.send('debugger.getConsoleContents');
    return response.result as String?;
  }

  Future<void> clearBreakpoints() async {
    await tools.tabInstance.send('debugger.clearBreakpoints');
  }

  Future<void> addBreakpoint(String path, int line) async {
    await tools.tabInstance.send('debugger.addBreakpoint', [path, line]);
  }

  Future<void> setIsolatePauseMode(String mode) async {
    await tools.tabInstance.send('debugger.setIsolatePauseMode', mode);
  }

  Future<List<String>> getBreakpoints() async {
    final response = await tools.tabInstance.send('debugger.getBreakpoints');
    final result = response.result as List<Object?>;
    return result.cast<String>();
  }

  Future<List<String>> getScripts() async {
    final response = await tools.tabInstance.send('debugger.getScripts');
    final result = response.result as List<Object?>;
    return result.cast<String>();
  }

  Future<bool> supportsScripts() async {
    final response = await tools.tabInstance.send('debugger.supportsScripts');
    return response.result as bool;
  }

  Future<List<String>> getCallStackFrames() async {
    final response =
        await tools.tabInstance.send('debugger.getCallStackFrames');
    final result = response.result as List<Object?>;
    return result.cast<String>();
  }
}
