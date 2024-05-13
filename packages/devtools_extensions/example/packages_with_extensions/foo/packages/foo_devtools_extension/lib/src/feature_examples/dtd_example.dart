// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';

import '../common/ui.dart';

/// This widget shows an example of how you can call public APIs exposed by
/// the Dart Tooling Daemon.
class DartToolingDaemonExample extends StatefulWidget {
  const DartToolingDaemonExample({super.key});

  @override
  State<DartToolingDaemonExample> createState() =>
      _DartToolingDaemonExampleState();
}

class _DartToolingDaemonExampleState extends State<DartToolingDaemonExample> {
  var workspaceRoots = <Uri>[];
  var projectRoots = <Uri>[];

  @override
  void initState() {
    super.initState();
    unawaited(_updateRoots());
  }

  Future<void> _updateRoots() async {
    workspaceRoots =
        (await dtdManager.workspaceRoots())?.ideWorkspaceRoots ?? [];
    projectRoots = (await dtdManager.projectRoots())?.uris ?? [];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          number: 5,
          title: 'Example of calling Dart Tooling Daemon APIs (requires a '
              'connected DTD instance)',
        ),
        _RootsList(
          roots: projectRoots,
          description: 'IDE workspace',
          onRefresh: _updateRoots,
        ),
        const SizedBox(height: defaultSpacing),
        _RootsList(
          roots: projectRoots,
          description: 'project',
          onRefresh: _updateRoots,
        ),
      ],
    );
  }
}

class _RootsList extends StatelessWidget {
  const _RootsList({
    required this.roots,
    required this.description,
    required this.onRefresh,
  });

  final List<Uri> roots;
  final String description;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Get $description roots:'),
            const SizedBox(height: densePadding),
            IconButton(
              icon: const Icon(Icons.refresh),
              iconSize: defaultIconSize,
              onPressed: onRefresh,
            ),
          ],
        ),
        const SizedBox(height: densePadding),
        SizedBox(
          height: 60.0,
          child: RoundedOutlinedBorder(
            child: ListView(
              children: [
                for (final root in roots) Text('$root'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

extension DTDExtension on DTDManager {
  DartToolingDaemon get _dtd => connection.value!;

  Future<String> readFile(Uri uri) async {
    if (!hasConnection) return '';
    try {
      final response = await _dtd.readFileAsString(uri);
      return response.content ?? '';
    } catch (_) {
      // Fail gracefully.
      return '';
    }
  }

  Future<void> writeFile(Uri uri, String contents) async {
    if (!hasConnection) return;
    try {
      await _dtd.writeFileAsString(uri, contents);
    } catch (_) {
      return;
    }
  }

  Future<List<Uri>> listDirectoryContents(Uri uri) async {
    if (!hasConnection) return [];
    try {
      final response = await _dtd.listDirectoryContents(uri);
      return response.uris ?? [];
    } catch (_) {
      // Fail gracefully.
      return [];
    }
  }
}
