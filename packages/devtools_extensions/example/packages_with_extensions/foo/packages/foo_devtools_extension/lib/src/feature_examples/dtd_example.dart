// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/api.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

/// This widget shows an example of how you can call public APIs exposed by
/// the Dart Tooling Daemon.
class DartToolingDaemonExample extends StatelessWidget {
  const DartToolingDaemonExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          number: 5,
          title: 'Example of calling Dart Tooling Daemon APIs',
        ),
      ],
    );
  }
}

extension DTDExtension on DTDManager {
  DartToolingDaemon get _dtd => connection.value!;

  Future<String?> readFile(Uri uri) async {
    if (!hasConnection) return;
    try {
      final response = await _dtd.readFileAsString(uri);
      return response.content;
    } catch (_) {
      // Fail gracefully.
      return '';
    }
  }

  Future<void> writeFile(Uri uri, String contents) async {
    if (!hasConnection) return;
    try {
      final response = await _dtd.writeFileAsString(uri, contents);
    } catch (_) {
      // Fail gracefully.
      return;
    }
  }

  Future<List<Uri>> listDirectoryContents(Uri uri) async {
    if (!hasConnection) return;
    try {
      final response = await _dtd.listDirectoryContents(uri, contents);
      return response.uris ?? [];
    } catch (_) {
      // Fail gracefully.
      return;
    }
  }
  
}
