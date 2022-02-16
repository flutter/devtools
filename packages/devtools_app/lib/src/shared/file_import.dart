// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: import_of_legacy_library_into_null_safe

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../config_specific/drag_and_drop/drag_and_drop.dart';
import '../primitives/utils.dart';
import '../ui/label.dart';
import 'common_widgets.dart';
import 'notifications.dart';
import 'theme.dart';
import 'utils.dart';

class FileImportContainer extends StatefulWidget {
  const FileImportContainer({
    required this.title,
    required this.instructions,
    this.actionText,
    this.onAction,
    this.onFileSelected,
    this.onFileCleared,
    this.onError,
    this.extensions = const ['json'],
    Key? key,
  }) : super(key: key);

  final String title;

  final String instructions;

  /// The title of the action button.
  final String? actionText;

  final DevToolsJsonFileHandler? onAction;

  final DevToolsJsonFileHandler? onFileSelected;

  final VoidCallback? onFileCleared;

  final void Function(String error)? onError;

  /// The file's extensions where we are going to get the data from.
  final List<String> extensions;

  @override
  _FileImportContainerState createState() => _FileImportContainerState();
}

class _FileImportContainerState extends State<FileImportContainer> {
  DevToolsJsonFile? importedFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          widget.title,
          style: TextStyle(fontSize: scaleByFontFactor(18.0)),
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
          color: Theme.of(context).textTheme.headline1!.color,
        ),
      ),
    );
  }

  Widget _buildImportFileRow() {
    final rowHeight = defaultButtonHeight;
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Horizontal spacer with flex value of 1.
        Flexible(
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
        const SizedBox(width: denseSpacing),
        FileImportButton(onPressed: _importFile),
        // Horizontal spacer with flex value of 1.
        Flexible(
          child: SizedBox(height: rowHeight),
        ),
      ],
    );
  }

  Widget _buildImportedFileDisplay() {
    return Row(
      children: [
        Expanded(
          child: Text(
            importedFile?.path ?? 'No File Selected',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).textTheme.headline1!.color,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        if (importedFile != null) clearInputButton(_clearFile),
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
                  ? () => widget.onAction!(importedFile!)
                  : null,
              child: MaterialIconLabel(
                label: widget.actionText,
                iconData: Icons.highlight,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importFile() async {
    final importedFile =
        await importFileFromPicker(acceptedTypes: widget.extensions);
    if (importedFile != null) {
      _handleImportedFile(importedFile);
    }
  }

  void _clearFile() {
    if (mounted) {
      setState(() {
        importedFile = null;
      });
    }
    if (widget.onFileCleared != null) {
      widget.onFileCleared!();
    }
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
      widget.onFileSelected!(file);
    }
  }
}

Future<DevToolsJsonFile?> importFileFromPicker({
  required List<String> acceptedTypes,
}) async {
  final acceptedTypeGroups = [XTypeGroup(extensions: acceptedTypes)];
  final file = await openFile(acceptedTypeGroups: acceptedTypeGroups);
  if (file == null) return null;

  final data = jsonDecode(await file.readAsString());
  final lastModifiedTime = await file.lastModified();
  // TODO(kenz): this will need to be modified if we need to support other file
  // extensions than .json. We will need to return a more generic file type.
  return DevToolsJsonFile(
    data: data,
    name: file.name ?? '',
    lastModifiedTime: lastModifiedTime,
  );
}

class FileImportButton extends StatelessWidget {
  const FileImportButton({
    required this.onPressed,
    this.elevatedButton = false,
  });

  final VoidCallback onPressed;

  final bool elevatedButton;

  @override
  Widget build(BuildContext context) {
    return IconLabelButton(
      onPressed: onPressed,
      icon: Icons.file_upload,
      label: 'Import File',
      elevatedButton: elevatedButton,
    );
  }
}

class DualFileImportContainer extends StatefulWidget {
  const DualFileImportContainer({
    required this.firstFileTitle,
    required this.secondFileTitle,
    required this.firstInstructions,
    required this.secondInstructions,
    required this.actionText,
    required this.onAction,
    Key? key,
  });

  final String firstFileTitle;

  final String secondFileTitle;

  final String firstInstructions;

  final String secondInstructions;

  /// The title of the action button.
  final String actionText;

  final Function(
    DevToolsJsonFile? firstImportedFile,
    DevToolsJsonFile? secondImportedFile,
    void Function(String error) onError,
  ) onAction;

  @override
  _DualFileImportContainerState createState() =>
      _DualFileImportContainerState();
}

class _DualFileImportContainerState extends State<DualFileImportContainer> {
  DevToolsJsonFile? firstImportedFile;
  DevToolsJsonFile? secondImportedFile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FileImportContainer(
            title: widget.firstFileTitle,
            instructions: widget.firstInstructions,
            onFileSelected: onFirstFileSelected,
            onFileCleared: onFirstFileCleared,
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
            onFileCleared: onSecondFileCleared,
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

  void onFirstFileCleared() {
    if (mounted) {
      setState(() {
        firstImportedFile = null;
      });
    }
  }

  void onSecondFileCleared() {
    if (mounted) {
      setState(() {
        secondImportedFile = null;
      });
    }
  }

  Widget _buildActionButton() {
    final notifications = Notifications.of(context)!;

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
                label: widget.actionText,
                iconData: Icons.highlight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
