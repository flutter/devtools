// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';

import 'server.dart';

const commandDescription =
    'Open DevTools (optionally connecting to an existing application).';

class DevToolsCommand extends Command<int> {
  DevToolsCommand({
    this.customDevToolsPath,
    bool verbose = false,
    this.hidden = false,
  }) {
    configureArgsParser(argParser, verbose);
  }

  @override
  final bool hidden;

  final String? customDevToolsPath;

  @override
  String get name => 'devtools';

  @override
  String get description => commandDescription;

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
