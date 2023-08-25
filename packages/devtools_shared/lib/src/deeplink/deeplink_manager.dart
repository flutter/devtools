// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart' as shelf;

import '../server/server_api.dart';

class DeeplinkManager {
  static final _buildVariantJsonRegex = RegExp(r'(\[.*\])');


  @visibleForTesting
  Future<ProcessResult> runProcess(String executable, List<String> arguments) {
    return Process.run(executable, arguments);
  }

  Future<shelf.Response> getBuildVariants({
    required String rootPath,
    required ServerApi api,
  }) async {
    final ProcessResult result = await runProcess(
      'flutter',
      <String>['analyze', '--android', '--list-build-variants', rootPath],
    );
    if (result.exitCode != 0) {
      return api.serverError(result.stderr);
    }
    final match = _buildVariantJsonRegex.firstMatch(result.stdout);
    final String outputJson;
    if (match == null) {
      outputJson = '[]';
    } else {
      outputJson = match.group(1)!;
    }
    return api.getCompleted(outputJson);
  }
}