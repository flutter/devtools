// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:path/path.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../ui/label.dart';

class FileImportContainer extends StatefulWidget {
  const FileImportContainer({
    @required this.title,
    @required this.fileToBeImported,
    this.actionText,
    this.onAction,
    this.onFileSelected,
    Key key,
  }) : super(key: key);

  final String title;

  /// The title of the action button.
  final String actionText;

  final Function(String filePath) onAction;

  final Function(String filePath) onFileSelected;

  // TODO(peterdjlee): Remove once the file picker is implemented.
  final String fileToBeImported;

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
          child: RoundedOutlinedBorder(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    _buildImportButton(),
                    _buildImportedFileDisplay(context),
                  ],
                ),
                if (widget.actionText != null && widget.onAction != null)
                  _buildActionButton(),
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
          importedFile != null ? importedFile : 'No File Selected',
          style: TextStyle(
            color: Theme.of(context).textTheme.headline1.color,
          ),
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
              importedFile = widget.fileToBeImported;
            });

            if (widget.onFileSelected != null) {
              widget.onFileSelected(importedFile);
            }
          },
          child: const MaterialIconLabel(Icons.file_upload, 'Import File'),
        ),
      ],
    );
  }

  Column _buildActionButton() {
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
                widget.actionText,
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
    @required this.firstFileTitle,
    @required this.secondFileTitle,
    @required this.actionText,
    @required this.onAction,
    Key key,
  }) : super(key: key);

  final String firstFileTitle;

  final String secondFileTitle;

  /// The title of the action button.
  final String actionText;

  final Function(String firstFilePath, String secondFilePath) onAction;

  @override
  _DualFileImportContainerState createState() =>
      _DualFileImportContainerState();
}

class _DualFileImportContainerState extends State<DualFileImportContainer> {
  String firstFilePath;
  String secondFilePath;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FileImportContainer(
            title: widget.firstFileTitle,
            onFileSelected: onFirstFileSelected,
            fileToBeImported: '$current/lib/src/code_size/stub_data/old_v8.dart',
          ),
        ),
        const SizedBox(width: defaultSpacing),
        Center(child: _buildActionButton()),
        const SizedBox(width: defaultSpacing),
        Expanded(
          child: FileImportContainer(
            title: widget.secondFileTitle,
            onFileSelected: onSecondFileSelected,
            fileToBeImported: '$current/lib/src/code_size/stub_data/new_v8.dart',
          ),
        ),
      ],
    );
  }

  void onFirstFileSelected(String selectedFirstFilePath) {
    setState(() {
      firstFilePath = selectedFirstFilePath;
    });
  }

  void onSecondFileSelected(String selectedSecondFilePath) {
    setState(() {
      secondFilePath = selectedSecondFilePath;
    });
  }

  Column _buildActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RaisedButton(
              onPressed: firstFilePath != null && secondFilePath != null
                  ? () => widget.onAction(firstFilePath, secondFilePath)
                  : null,
              child: MaterialIconLabel(
                Icons.highlight,
                widget.actionText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
