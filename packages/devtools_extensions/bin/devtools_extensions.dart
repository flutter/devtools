// Copyright 2023 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:args/command_runner.dart';
import 'package:io/io.dart';

import '_build_and_copy.dart';
import '_validate.dart';

void main(List<String> arguments) async {
  final command = BuildExtensionCommand();
  final runner = CommandRunner('devtools_extensions', command.description)
    ..addCommand(BuildExtensionCommand())
    ..addCommand(ValidateExtensionCommand());
  await runner.run(arguments).whenComplete(sharedStdIn.terminate);
}
