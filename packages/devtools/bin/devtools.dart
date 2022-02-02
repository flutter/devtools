// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:isolate';

import 'package:dds/devtools_server.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  // ignore: unawaited_futures
  // TODO(kenz): uncomment this out once a new version of dds is published.
  // unawaited(DevToolsServer().serveDevToolsWithArgs(arguments));
  final buildDir = await _resolveBuildDir();
  unawaited(DevToolsServer().serveDevTools(customDevToolsPath: buildDir));
}

Future<String> _resolveBuildDir() async {
  final resourceUri = await Isolate.resolvePackageUri(
    Uri(
      scheme: 'package',
      path: 'devtools/devtools.dart',
    ),
  );

  final packageDir = path.dirname(path.dirname(resourceUri!.toFilePath()));
  return path.join(packageDir, 'build');
}
