// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';

import '../devtools_server.dart';
import 'server.dart';

class DevToolsCommand extends Command<int> {
  DevToolsCommand({
    this.customDevToolsPath,
    bool verbose = false,
  }) {
    configureArgsParser(argParser, verbose);
  }

  final String? customDevToolsPath;

  @override
  String get name => 'devtools';

  @override
  String get description =>
      'Open a DevTools instance in a browser and optionally connect to an existing application.';

  @override
  String get invocation => '${super.invocation} [service protocol uri]';

  @override
  Future<int> run() async {
    final server = await serveDevToolsWithArgs(
      argResults!.arguments,
      customDevToolsPath: customDevToolsPath,
    );

    return server == null ? -1 : 0;
  }
}
