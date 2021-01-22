// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../common_widgets.dart';
import '../config_specific/drag_and_drop/drag_and_drop.dart';
import '../notifications.dart';
import '../theme.dart';
import '../ui/label.dart';
import '../utils.dart';

class FileImportContainer extends StatefulWidget {
  const FileImportContainer({
    @required this.title,
    @required this.instructions,
    this.actionText,
    this.onAction,
    this.onFileSelected,
    this.onError,
    this.extensions = const ['json'],
    Key key,
  }) : super(key: key);

  final String title;

  final String instructions;

  /// The title of the action button.
  final String actionText;

  final DevToolsJsonFileHandler onAction;

  final DevToolsJsonFileHandler onFileSelected;

  final void Function(String error) onError;

  /// The file's extensions where we are going to get the data from.
  final List<String> extensions;

  @override
  _FileImportContainerState createState() => _FileImportContainerState();
}

class _FileImportContainerState extends State<FileImportContainer> {
  DevToolsJsonFile importedFile;

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
          // TODO(kenz): improve drag over highlight.
          child: DragAndDrop(
            handleDrop: _handleImportedFile,
            child: RoundedOutlinedBorder(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildImportInstructions(),
                    _buildImportFileRow(),
                    if (widget.actionText != null && widget.onAction != null)
                      _buildActionButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImportInstructions() {
    return Padding(
      padding: const EdgeInsets.all(defaultSpacing),
      child: Text(
        widget.instructions,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).textTheme.headline1.color,
        ),
      ),
    );
  }

  Widget _buildImportFileRow() {
    const rowHeight = 37.0;
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Horizontal spacer with flex value of 1.
        const Flexible(
          child: SizedBox(height: rowHeight),
        ),
        Flexible(
          flex: 4,
          fit: FlexFit.tight,
          child: Container(
            height: rowHeight,
            padding: const EdgeInsets.all(denseSpacing),
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.all(Radius.circular(defaultBorderRadius)),
              border: Border(
                top: BorderSide(color: theme.focusColor),
                bottom: BorderSide(color: theme.focusColor),
                left: BorderSide(color: theme.focusColor),
                // TODO(kenz): remove right border when we add the import button
                right: BorderSide(color: theme.focusColor),
              ),
            ),
            child: _buildImportedFileDisplay(),
          ),
        ),
        _buildImportButton(),
        // Horizontal spacer with flex value of 1.
        const Flexible(
          child: SizedBox(height: rowHeight),
        ),
      ],
    );
  }

  Widget _buildImportedFileDisplay() {
    return Text(
      importedFile?.path ?? 'No File Selected',
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Theme.of(context).textTheme.headline1.color,
      ),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildImportButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton(
          onPressed: _importFile,
          child: const MaterialIconLabel(Icons.file_upload, 'Import File'),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
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

  void _importFile() async {
    final acceptedTypeGroups = [XTypeGroup(extensions: widget.extensions)];
    final file = await openFile(acceptedTypeGroups: acceptedTypeGroups);
    final data = jsonDecode(await file.readAsString());
    final lastModifiedTime = await file.lastModified();
    final devToolsJsonFile = DevToolsJsonFile(
      data: data,
      name: file.name,
      lastModifiedTime: lastModifiedTime,
    );
    _handleImportedFile(devToolsJsonFile);
  }

  // TODO(kenz): add error handling to ensure we only allow importing supported
  // files.
  void _handleImportedFile(DevToolsJsonFile file) {
    // TODO(peterdjlee): Investigate why setState is called after the state is disposed.
    if (mounted) {
      setState(() {
        importedFile = file;
      });
    }
    if (widget.onFileSelected != null) {
      widget.onFileSelected(file);
    }
  }
}

class DualFileImportContainer extends StatefulWidget {
  const DualFileImportContainer({
    @required this.firstFileTitle,
    @required this.secondFileTitle,
    @required this.firstInstructions,
    @required this.secondInstructions,
    @required this.actionText,
    @required this.onAction,
    Key key,
  });

  final String firstFileTitle;

  final String secondFileTitle;

  final String firstInstructions;

  final String secondInstructions;

  /// The title of the action button.
  final String actionText;

  final Function(
    DevToolsJsonFile firstImportedFile,
    DevToolsJsonFile secondImportedFile,
    void Function(String error) onError,
  ) onAction;

  @override
  _DualFileImportContainerState createState() =>
      _DualFileImportContainerState();
}

class _DualFileImportContainerState extends State<DualFileImportContainer> {
  DevToolsJsonFile firstImportedFile;
  DevToolsJsonFile secondImportedFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FileImportContainer(
            title: widget.firstFileTitle,
            instructions: widget.firstInstructions,
            onFileSelected: onFirstFileSelected,
          ),
        ),
        const SizedBox(width: defaultSpacing),
        Center(child: _buildActionButton()),
        const SizedBox(width: defaultSpacing),
        Expanded(
          child: FileImportContainer(
            title: widget.secondFileTitle,
            instructions: widget.secondInstructions,
            onFileSelected: onSecondFileSelected,
          ),
        ),
      ],
    );
  }

  void onFirstFileSelected(DevToolsJsonFile selectedFile) {
    // TODO(peterdjlee): Investigate why setState is called after the state is disposed.
    if (mounted) {
      setState(() {
        firstImportedFile = selectedFile;
      });
    }
  }

  void onSecondFileSelected(DevToolsJsonFile selectedFile) {
    // TODO(peterdjlee): Investigate why setState is called after the state is disposed.
    if (mounted) {
      setState(() {
        secondImportedFile = selectedFile;
      });
    }
  }

  Widget _buildActionButton() {
    final notifications = Notifications.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: firstImportedFile != null && secondImportedFile != null
                  ? () => widget.onAction(
                        firstImportedFile,
                        secondImportedFile,
                        (error) => notifications.push(error),
                      )
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
