// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:http_server/http_server.dart' show VirtualDirectory;
import 'package:path/path.dart';

final webroot = join(dirname(dirname(Platform.script.toFilePath())), 'build');

Future<void> main() async {
  final virDir = new VirtualDirectory(webroot);

  // Set up a directory handler to serve index.html files.
  virDir.allowDirectoryListing = true;
  virDir.directoryHandler = (dir, request) {
    final indexUri = new Uri.file(dir.path).resolve('index.html');
    virDir.serveFile(new File(indexUri.toFilePath()), request);
  };

  // TODO(dantup): How to decide port?
  final server = await HttpServer.bind('127.0.0.1', 8765);

  virDir.serve(server);
  printJson({'host': server.address.host, 'port': server.port});
}

void printJson(Object obj) {
  print(jsonEncode(obj));
}
