// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:devtools_tool/commands/build.dart';
import 'package:devtools_tool/commands/fix_goldens.dart';
import 'package:devtools_tool/commands/generate_code.dart';
import 'package:devtools_tool/commands/serve.dart';
import 'package:devtools_tool/commands/sync.dart';
import 'package:devtools_tool/commands/tag_version.dart';
import 'package:devtools_tool/commands/update_flutter_sdk.dart';
import 'package:devtools_tool/commands/update_perfetto.dart';
import 'package:devtools_tool/model.dart';

import 'commands/analyze.dart';
import 'commands/list.dart';
import 'commands/pub_get.dart';
import 'commands/release_helper.dart';
import 'commands/repo_check.dart';
import 'commands/rollback.dart';
import 'commands/update_dart_sdk_deps.dart';
import 'commands/update_version.dart';

const _flutterFromPathFlag = 'flutter-from-path';

class DevToolsCommandRunner extends CommandRunner {
  DevToolsCommandRunner()
      : super('devtools_tool', 'A repo management tool for DevTools.') {
    addCommand(AnalyzeCommand());
    addCommand(BuildCommand());
    addCommand(FixGoldensCommand());
    addCommand(GenerateCodeCommand());
    addCommand(ListCommand());
    addCommand(PubGetCommand());
    addCommand(ReleaseHelperCommand());
    addCommand(RepoCheckCommand());
    addCommand(RollbackCommand());
    addCommand(ServeCommand());
    addCommand(SyncCommand());
    addCommand(TagVersionCommand());
    addCommand(UpdateDartSdkDepsCommand());
    addCommand(UpdateDevToolsVersionCommand());
    addCommand(UpdateFlutterSdkCommand());
    addCommand(UpdatePerfettoCommand());

    argParser.addFlag(
      _flutterFromPathFlag,
      abbr: 'p',
      negatable: false,
      help: 'Use the Flutter SDK on PATH for any `flutter`, `dart` and '
          '`devtools_tool` commands spawned by this process, instead of the '
          'Flutter SDK from tool/flutter-sdk which is used by default.',
    );
  }

  @override
  Future<void> runCommand(ArgResults topLevelResults) {
    if (topLevelResults[_flutterFromPathFlag]) {
      FlutterSdk.useFromPathEnvironmentVariable();
    } else {
      FlutterSdk.useFromCurrentVm();
    }
    print('Using Flutter SDK from ${FlutterSdk.current.sdkPath}');

    return super.runCommand(topLevelResults);
  }
}
