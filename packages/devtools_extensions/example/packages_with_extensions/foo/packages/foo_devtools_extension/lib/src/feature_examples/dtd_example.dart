// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:dtd/dtd.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

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
        _RootsList(
          roots: workspaceRoots,
          description: 'IDE workspace',
          onRefresh: _updateRoots,
        ),
        const SizedBox(height: defaultSpacing),
        _RootsList(
          roots: projectRoots,
          description: 'project',
          onRefresh: _updateRoots,
        ),
        const SizedBox(height: defaultSpacing),
        if (workspaceRoots.isNotEmpty)
          ReadWriteTmpFile(root: workspaceRoots.first),
        // TODO(kenz): make this a link once the LinkTextSpan utility is exposed
        // in devtools_app_shared.
        const Text(
          'Explore package:dtd to learn about all the things you can do with '
          'the Dart Tooling Daemon.',
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
            const SizedBox(width: densePadding),
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
            child: Padding(
              padding: const EdgeInsets.all(densePadding),
              child: ListView(
                children: [
                  for (final root in roots) Text('$root'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReadWriteTmpFile extends StatefulWidget {
  const ReadWriteTmpFile({required this.root, super.key});

  final Uri root;

  @override
  State<ReadWriteTmpFile> createState() => _ReadWriteTmpFileState();
}

class _ReadWriteTmpFileState extends State<ReadWriteTmpFile> {
  late final TextEditingController textEditingController;
  late final Uri tmpFileUri;
  String tmpFileContent = '';

  @override
  void initState() {
    super.initState();
    tmpFileUri = Uri.parse(p.join(widget.root.toString(), 'tmp.txt'));
    textEditingController = TextEditingController();
  }

  Future<void> _writeFilesAndUpdate() async {
    await dtdManager.writeFile(tmpFileUri, textEditingController.text);
    await _readTmpFile();
  }

  Future<void> _readTmpFile() async {
    final content = await dtdManager.readFile(tmpFileUri);
    setState(() {
      tmpFileContent = content;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Reading and writing to a file within a workspace root: ',
            style: theme.regularTextStyle,
            children: [
              TextSpan(
                text: p.join(widget.root.toString(), 'tmp.txt'),
                style: theme.regularTextStyleWithColor(
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: denseSpacing),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Write to tmp.txt'),
                  const SizedBox(height: densePadding),
                  SizedBox(
                    height: 60.0,
                    child: RoundedOutlinedBorder(
                      child: Padding(
                        padding: const EdgeInsets.all(densePadding),
                        child: TextField(
                          controller: textEditingController,
                          maxLines: 4,
                          minLines: 2,
                          style: theme.regularTextStyle,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Write something...',
                            hintStyle: theme.subtleTextStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
              child: DevToolsButton(
                label: 'Write',
                icon: Icons.edit,
                onPressed: _writeFilesAndUpdate,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Read from tmp.txt'),
                  const SizedBox(height: densePadding),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 60.0,
                          child: RoundedOutlinedBorder(
                            child: Padding(
                              padding: const EdgeInsets.all(densePadding),
                              child: Text(
                                tmpFileContent.isEmpty
                                    ? '<file is empty>'
                                    : tmpFileContent,
                                style: theme.subtleTextStyle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Extension methods on [DTDManager], which is a class provided by
/// package:devtools_extensions.
///
/// These extension methods are helpful for easier interaction with the current
/// [DartToolingDaemon] connection.
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
}
