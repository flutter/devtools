// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../theme.dart';
import '../ui/label.dart';

class FileImportContainer extends StatefulWidget {
  const FileImportContainer({
    @required this.title,
    this.actionText,
    this.onAction,
    this.onFileSelected,
    this.importNewFile = true,
    Key key,
  }) : super(key: key);

  final String title;

  /// The title of the action button.
  final String actionText;

  final Function(String filePath) onAction;

  final Function(String filePath) onFileSelected;

  // TODO(peterdjlee): Remove once the file picker is implemented.
  final bool importNewFile;

  @override
  _FileImportContainerState createState() => _FileImportContainerState();
}

class _FileImportContainerState extends State<FileImportContainer> {
  String importedFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 18.0),
        ),
        const SizedBox(height: defaultSpacing),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15.0),
              color: Theme.of(context).colorScheme.chartAccentColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    _buildImportButton(),
                    if (importedFile != null)
                      _buildImportedFileDisplay(context),
                  ],
                ),
                if (widget.actionText != null && widget.onAction != null)
                  _buildAnalyzeButton(widget.actionText),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Column _buildImportedFileDisplay(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Text(
          'Imported File:',
          textAlign: TextAlign.center,
        ),
        Text(
          importedFile,
          style: TextStyle(color: Theme.of(context).textTheme.headline1.color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Row _buildImportButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlineButton(
          onPressed: () {
            // TODO(peterdjlee): Prompt file picker to choose a file.
            setState(() {
              if (widget.importNewFile) {
                importedFile =
                    '$current/lib/src/code_size/stub_data/old_v8.json';
              } else {
                importedFile =
                    '$current/lib/src/code_size/stub_data/new_v8.json';
              }
            });

            if (widget.onFileSelected != null)
              widget.onFileSelected(importedFile);
          },
          child: const MaterialIconLabel(Icons.file_upload, 'Import File'),
        ),
      ],
    );
  }

  Column _buildAnalyzeButton(String title) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RaisedButton(
              onPressed: importedFile != null
                  ? () => widget.onAction(importedFile)
                  : null,
              child: MaterialIconLabel(
                Icons.highlight,
                title,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class DualFileImportContainer extends StatefulWidget {
  const DualFileImportContainer({
    @required this.actionText,
    @required this.onAction,
    Key key,
  }) : super(key: key);

  /// The title of the action button.
  final String actionText;

  final Function(String oldFilePath, String newFilePath) onAction;

  @override
  _DualFileImportContainerState createState() =>
      _DualFileImportContainerState();
}

class _DualFileImportContainerState extends State<DualFileImportContainer> {
  String pathToOldFile;
  String pathToNewFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FileImportContainer(
            title: 'Old',
            onFileSelected: onOldFileImport,
            importNewFile: false,
          ),
        ),
        const SizedBox(width: defaultSpacing),
        Center(child: _buildAnalyzeButton('Analyze Diff')),
        const SizedBox(width: defaultSpacing),
        Expanded(
          child: FileImportContainer(
            title: 'New',
            onFileSelected: onNewFileImport,
          ),
        ),
      ],
    );
  }

  void onOldFileImport(String importedPathToOldFile) {
    setState(() {
      pathToOldFile = importedPathToOldFile;
    });
  }

  void onNewFileImport(String importedPathToNewFile) {
    setState(() {
      pathToNewFile = importedPathToNewFile;
    });
  }

  Column _buildAnalyzeButton(String title) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RaisedButton(
              onPressed: pathToOldFile != null && pathToNewFile != null
                  ? () => widget.onAction(pathToOldFile, pathToNewFile)
                  : null,
              child: MaterialIconLabel(
                Icons.highlight,
                title,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
