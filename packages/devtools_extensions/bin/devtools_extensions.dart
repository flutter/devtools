// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:args/command_runner.dart';
import '_build_and_copy.dart';

void main(List<String> arguments) async {
  final command = BuildExtensionCommand();
  final runner = CommandRunner('devtools_extensions', command.description)
    ..addCommand(BuildExtensionCommand());
  await runner.run(arguments);
}
