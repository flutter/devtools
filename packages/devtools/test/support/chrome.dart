// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:devtools/src/utils_io.dart';
import 'package:path/path.dart' as path;
import 'package:pedantic/pedantic.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    hide ChromeTab;
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    as wip show ChromeTab;

// Change this if you want to be able to see Chrome opening while tests run
// to aid debugging.
const _useChromeHeadless = true;

class Chrome {
  factory Chrome.from(String executable) {
    return FileSystemEntity.isFileSync(executable)
        ? Chrome._(executable)
        : null;
  }

  Chrome._(this.executable);

  static Chrome locate() {
    if (Platform.isMacOS) {
      const String defaultPath = '/Applications/Google Chrome.app';
      const String bundlePath = 'Contents/MacOS/Google Chrome';

      if (FileSystemEntity.isDirectorySync(defaultPath)) {
        return Chrome.from(path.join(defaultPath, bundlePath));
      }
    } else if (Platform.isLinux) {
      const String defaultPath = '/usr/bin/google-chrome';

      if (FileSystemEntity.isFileSync(defaultPath)) {
        return Chrome.from(defaultPath);
      }
    } else if (Platform.isWindows) {
      final String progFiles = Platform.environment['PROGRAMFILES(X86)'];
      final String chromeInstall = '$progFiles\\Google\\Chrome';
      final String defaultPath = '$chromeInstall\\Application\\chrome.exe';

      if (FileSystemEntity.isFileSync(defaultPath)) {
        return Chrome.from(defaultPath);
      }
    }

    // TODO(devoncarew): check default install locations for linux
    // TODO(devoncarew): try `which` on mac, linux

    return null;
  }

  /// Return the path to a per-user Chrome data dir.
  ///
  /// This method will create the directory if it does not exist.
  static String getCreateChromeDataDir() {
    final Directory prefsDir = getDartPrefsDirectory();
    final Directory chromeDataDir =
        Directory(path.join(prefsDir.path, 'chrome'));
    if (!chromeDataDir.existsSync()) {
      chromeDataDir.createSync(recursive: true);
    }
    return chromeDataDir.path;
  }

  final String executable;

  Future<ChromeProcess> start({String url, int debugPort = 9222}) {
    final List<String> args = <String>[
      '--no-default-browser-check',
      '--no-first-run',
      '--user-data-dir=${getCreateChromeDataDir()}',
      '--remote-debugging-port=$debugPort'
    ];
    // TODO(dantup): Chrome headless currently hangs on Windows (both Travis and
    // locally), so use non-headless there until we have a fix.
    if (_useChromeHeadless && !Platform.isWindows) {
      args.addAll(<String>[
        '--headless',
        '--disable-gpu',
        '--no-sandbox',
      ]);
    }
    if (url != null) {
      args.add(url);
    }
    return Process.start(executable, args).then((Process process) {
      return ChromeProcess(process, debugPort);
    });
  }
}

class ChromeProcess {
  ChromeProcess(this.process, this.debugPort);

  final Process process;
  final int debugPort;
  bool _processAlive = true;

  Future<ChromeTab> connectToTab(
    String url, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ChromeConnection connection =
        ChromeConnection(Uri.parse(url).host, debugPort);

    final wip.ChromeTab wipTab = await connection.getTab((wip.ChromeTab tab) {
      return tab.url == url;
    }, retryFor: timeout);

    unawaited(process.exitCode.then((_) {
      _processAlive = false;
    }));

    return wipTab == null ? null : ChromeTab(wipTab);
  }

  Future<ChromeTab> connectToTabId(
    String host,
    String id, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ChromeConnection connection = ChromeConnection(host, debugPort);

    final wip.ChromeTab wipTab = await connection.getTab((wip.ChromeTab tab) {
      return tab.id == id;
    }, retryFor: timeout);

    unawaited(process.exitCode.then((_) {
      _processAlive = false;
    }));

    return wipTab == null ? null : ChromeTab(wipTab);
  }

  Future<ChromeTab> getFirstTab({
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final ChromeConnection connection =
        ChromeConnection('localhost', debugPort);

    final wip.ChromeTab wipTab = await connection.getTab((wip.ChromeTab tab) {
      return !tab.isBackgroundPage && !tab.isChromeExtension;
    }, retryFor: timeout);

    unawaited(process.exitCode.then((_) {
      _processAlive = false;
    }));

    return wipTab == null ? null : ChromeTab(wipTab);
  }

  bool get isAlive => _processAlive;

  /// Returns `true` if the signal is successfully delivered to the process.
  /// Otherwise the signal could not be sent, usually meaning that the process
  /// is already dead.
  bool kill() => process.kill();

  Future<int> get onExit => process.exitCode;
}

class ChromeTab {
  ChromeTab(this.wipTab);

  final wip.ChromeTab wipTab;
  WipConnection _wip;

  final StreamController<Null> _disconnectStream =
      StreamController<Null>.broadcast();
  final StreamController<LogEntry> _entryAddedController =
      StreamController<LogEntry>.broadcast();
  final StreamController<ConsoleAPIEvent> _consoleAPICalledController =
      StreamController<ConsoleAPIEvent>.broadcast();
  final StreamController<ExceptionThrownEvent> _exceptionThrownController =
      StreamController<ExceptionThrownEvent>.broadcast();

  num _lostConnectionTime;

  Future<WipConnection> connect({bool verbose = false}) async {
    _wip = await wipTab.connect();

    await _wip.log.enable();
    _wip.log.onEntryAdded.listen((LogEntry entry) {
      if (_lostConnectionTime == null ||
          entry.timestamp > _lostConnectionTime) {
        _entryAddedController.add(entry);
      }
    });

    await _wip.runtime.enable();
    _wip.runtime.onConsoleAPICalled.listen((ConsoleAPIEvent event) {
      if (_lostConnectionTime == null ||
          event.timestamp > _lostConnectionTime) {
        _consoleAPICalledController.add(event);
      }
    });

    unawaited(
        _exceptionThrownController.addStream(_wip.runtime.onExceptionThrown));

    unawaited(_wip.page.enable());

    _wip.onClose.listen((_) {
      _wip = null;
      _disconnectStream.add(null);
      _lostConnectionTime = DateTime.now().millisecondsSinceEpoch;
    });

    if (verbose) {
      onLogEntryAdded.listen((entry) {
        print('chrome • log:${entry.source} • ${entry.text} ${entry.url}');
      });

      onConsoleAPICalled.listen((entry) {
        print('chrome • console:${entry.type} • '
            '${entry.args.map((a) => a.value).join(', ')}');
      });

      onExceptionThrown.listen((ex) {
        throw 'JavaScript exception occurred: ${ex.method}\n\n'
            '${ex.params}\n\n'
            '${ex.exceptionDetails?.text}\n\n'
            '${ex.exceptionDetails?.exception}\n\n'
            '${ex.exceptionDetails?.stackTrace}';
      });
    }

    return _wip;
  }

  Future<String> createNewTarget() {
    return _wip.target.createTarget('about:blank');
  }

  bool get isConnected => _wip != null;

  Stream<Null> get onDisconnect => _disconnectStream.stream;

  Stream<LogEntry> get onLogEntryAdded => _entryAddedController.stream;

  Stream<ConsoleAPIEvent> get onConsoleAPICalled =>
      _consoleAPICalledController.stream;

  Stream<ExceptionThrownEvent> get onExceptionThrown =>
      _exceptionThrownController.stream;

  Future<Null> reload() => _wip.page.reload();

  Future<dynamic> navigate(String url) => _wip.page.navigate(url);

  WipConnection get wipConnection => _wip;
}
