import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

import 'io_utils.dart';
import 'test_app_driver/driver.dart';

void main(List<String> args) async {
  TestFlutterApp? testApp;
  String? testAppUri;

  const testAppArg = '--test-app-uri=';

  final argWithTestAppUri =
      args.firstWhereOrNull((arg) => arg.startsWith(testAppArg));
  final createTestApp = argWithTestAppUri == null;

  if (createTestApp) {
    testApp = TestFlutterApp();
    await testApp.start();
    testAppUri = testApp.vmServiceUri.toString();
  } else {
    testAppUri = argWithTestAppUri.substring(testAppArg.length);
  }

  final chromedriver = ChromeDriver();
  await chromedriver.start();

  final headless = args.contains('--headless');
  final testArgs = {
    'service_uri': testAppUri,
  };
  final testRunner = TestRunner();
  await testRunner.run(headless: headless, args: testArgs);

  if (createTestApp) {
    _debugLog('killing the test app');
    await testApp?.killGracefully();
  }

  _debugLog('cancelling stream subscriptions');
  await testRunner.cancelAllStreamSubscriptions();
  await chromedriver.cancelAllStreamSubscriptions();
  _debugLog('end of main');
}

class ChromeDriver with IoMixin {
  // TODO(kenz): add error messaging if the chromedriver executable is not found
  Future<void> start() async {
    _debugLog('starting the chromedriver process');
    final process = await Process.start(
      'chromedriver',
      [
        '--port=4444',
      ],
    );
    listenToProcessOutput(process);
  }
}

class TestRunner with IoMixin {
  Future<void> run({
    bool headless = false,
    Map<String, Object> args = const <String, Object>{},
  }) async {
    _debugLog('starting the flutter drive process');
    final process = await Process.start(
      'flutter',
      [
        'drive',
        '--driver=test_driver/integration_test.dart',
        '--target=integration_test/app_test.dart',
        '-d',
        headless ? 'web-server' : 'chrome',
        if (args.isNotEmpty) '--dart-define=test_args=${jsonEncode(args)}'
      ],
    );
    listenToProcessOutput(process);

    await process.exitCode;
    _debugLog('flutter drive process has exited');
  }
}

bool _debugTestScript = true;
void _debugLog(String log) {
  if (_debugTestScript) {
    print(log);
  }
}
