// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'analytics/analytics.dart' as ga;
import 'analytics/constants.dart' as gac;
import 'common_widgets.dart';
import 'config_specific/drag_and_drop/drag_and_drop.dart';
import 'config_specific/import_export/import_export.dart';
import 'globals.dart';
import 'primitives/utils.dart';

class OpenSaveButtonGroup extends StatelessWidget {
  const OpenSaveButtonGroup({
    super.key,
    required this.screenId,
    required this.onSave,
  });

  final String screenId;

  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return RoundedButtonGroup(
      items: [
        ButtonGroupItemData(
          icon: Icons.file_upload,
          tooltip: 'Open a file that was previously saved from DevTools',
          onPressed: () async {
            ga.select(screenId, gac.openFile);
            final importedFile =
                await importFileFromPicker(acceptedTypes: const ['json']);
            if (importedFile != null) {
              // ignore: use_build_context_synchronously, intentional use.
              Provider.of<ImportController>(context, listen: false)
                  .importData(importedFile, expectedScreenId: screenId);
            } else {
              notificationService.push(
                'Something went wrong. Could not open selected file.',
              );
            }
          },
        ),
        ButtonGroupItemData(
          icon: Icons.file_download,
          tooltip: 'Save this screen\'s data for offline viewing',
          onPressed: onSave != null
              ? () {
                  ga.select(screenId, gac.saveFile);
                  onSave!.call();
                }
              : null,
        ),
      ],
    );
  }
}

class FileImportContainer extends StatefulWidget {
  const FileImportContainer({
    required this.instructions,
    required this.gaScreen,
    required this.gaSelectionImport,
    this.title,
    this.gaSelectionAction,
    this.actionText,
    this.onAction,
    this.onFileSelected,
    this.onFileCleared,
    this.extensions = const ['json'],
    super.key,
  });

  final String? title;

  final String instructions;

  /// The title of the action button.
  final String? actionText;

  final DevToolsJsonFileHandler? onAction;

  final DevToolsJsonFileHandler? onFileSelected;

  final VoidCallback? onFileCleared;

  /// The file's extensions where we are going to get the data from.
  final List<String> extensions;

  final String gaScreen;

  final String gaSelectionImport;

  final String? gaSelectionAction;

  @override
  State<FileImportContainer> createState() => _FileImportContainerState();
}

class _FileImportContainerState extends State<FileImportContainer> {
  DevToolsJsonFile? importedFile;

  @override
  Widget build(BuildContext context) {
    final title = widget.title;
    return Column(
      children: [
        if (title != null) ...[
          Text(
            title,
            style: TextStyle(fontSize: scaleByFontFactor(18.0)),
          ),
          const SizedBox(height: defaultSpacing),
        ],
        Expanded(
          // TODO(kenz): improve drag over highlight.
          child: DragAndDrop(
            handleDrop: _handleImportedFile,
            child: RoundedOutlinedBorder(
              clip: true,
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CenteredMessage(widget.instructions),
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

  Widget _buildImportFileRow() {
    final rowHeight = defaultButtonHeight;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Flexible(
          flex: 4,
          fit: FlexFit.tight,
          child: RoundedOutlinedBorder(
            child: Container(
              height: rowHeight,
              padding: const EdgeInsets.symmetric(horizontal: defaultSpacing),
              child: _buildImportedFileDisplay(),
            ),
          ),
        ),
        const SizedBox(width: denseSpacing),
        FileImportButton(
          onPressed: _importFile,
          gaScreen: widget.gaScreen,
          gaSelection: widget.gaSelectionImport,
        ),
        const Spacer(),
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
            style: Theme.of(context).regularTextStyle,
            textAlign: TextAlign.left,
          ),
        ),
        if (importedFile != null) clearInputButton(_clearFile),
      ],
    );
  }

  Widget _buildActionButton() {
    assert(widget.actionText != null);
    assert(widget.onAction != null);
    assert(widget.gaSelectionAction != null);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GaDevToolsButton(
              gaScreen: widget.gaScreen,
              gaSelection: widget.gaSelectionAction!,
              label: widget.actionText!,
              elevated: true,
              onPressed: importedFile != null
                  ? () => widget.onAction!(importedFile!)
                  : null,
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
  return await _toDevToolsFile(file);
}

Future<List<XFile>> importRawFilesFromPicker({
  List<String>? acceptedTypes,
}) async {
  final acceptedTypeGroups = [XTypeGroup(extensions: acceptedTypes)];
  return await openFiles(acceptedTypeGroups: acceptedTypeGroups);
}

Future<DevToolsJsonFile> _toDevToolsFile(XFile file) async {
  final data = jsonDecode(await file.readAsString());
  final lastModifiedTime = await file.lastModified();
  // TODO(kenz): this will need to be modified if we need to support other file
  // extensions than .json. We will need to return a more generic file type.
  return DevToolsJsonFile(
    data: data,
    name: file.name,
    lastModifiedTime: lastModifiedTime,
  );
}

class FileImportButton extends StatelessWidget {
  const FileImportButton({
    super.key,
    required this.onPressed,
    required this.gaScreen,
    required this.gaSelection,
    this.elevatedButton = false,
  });

  final VoidCallback onPressed;
  final bool elevatedButton;
  final String gaScreen;
  final String gaSelection;

  @override
  Widget build(BuildContext context) {
    return GaDevToolsButton(
      onPressed: onPressed,
      icon: Icons.file_upload,
      label: 'Open file',
      gaScreen: gaScreen,
      gaSelection: gaSelection,
      elevated: elevatedButton,
    );
  }
}

class DualFileImportContainer extends StatefulWidget {
  const DualFileImportContainer({
    super.key,
    required this.firstFileTitle,
    required this.secondFileTitle,
    required this.firstInstructions,
    required this.secondInstructions,
    required this.actionText,
    required this.onAction,
    required this.gaScreen,
    required this.gaSelectionImportFirst,
    required this.gaSelectionImportSecond,
    required this.gaSelectionAction,
  });

  final String firstFileTitle;
  final String secondFileTitle;
  final String firstInstructions;
  final String secondInstructions;
  final String gaScreen;
  final String gaSelectionImportFirst;
  final String gaSelectionImportSecond;
  final String gaSelectionAction;

  /// The title of the action button.
  final String actionText;

  final void Function(
    DevToolsJsonFile firstImportedFile,
    DevToolsJsonFile secondImportedFile,
    void Function(String error) onError,
  ) onAction;

  @override
  State<DualFileImportContainer> createState() =>
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
            gaScreen: widget.gaScreen,
            gaSelectionImport: widget.gaSelectionImportFirst,
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
            gaScreen: widget.gaScreen,
            gaSelectionImport: widget.gaSelectionImportSecond,
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: defaultSpacing),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GaDevToolsButton(
              gaScreen: widget.gaScreen,
              gaSelection: widget.gaSelectionAction,
              label: widget.actionText,
              icon: Icons.highlight,
              elevated: true,
              onPressed: firstImportedFile != null && secondImportedFile != null
                  ? () => widget.onAction(
                        firstImportedFile!,
                        secondImportedFile!,
                        (error) => notificationService.push(error),
                      )
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
