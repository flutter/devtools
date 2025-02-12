// Copyright 2020 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import 'package:devtools_app_shared/ui.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../analytics/analytics.dart' as ga;
import '../analytics/constants.dart' as gac;
import '../config_specific/drag_and_drop/drag_and_drop.dart';
import '../config_specific/import_export/import_export.dart';
import '../globals.dart';
import '../primitives/utils.dart';
import 'common_widgets.dart';

enum SaveFormat {
  devtools('Save as DevTools .json file'),
  har('Save as .har file');

  const SaveFormat(this.display);

  final String display;

  static final dropdownWidth = scaleByFontFactor(200.0);
}

class OpenSaveButtonGroup extends StatelessWidget {
  const OpenSaveButtonGroup({
    super.key,
    required this.screenId,
    required this.onSave,
    this.saveFormats = const [SaveFormat.devtools],
    this.gaItemForSaveFormatSelection,
  }) : assert(saveFormats.length >= 1);

  final String screenId;

  final void Function(SaveFormat)? onSave;

  final List<SaveFormat> saveFormats;

  final String Function(SaveFormat)? gaItemForSaveFormatSelection;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: defaultButtonHeight,
      child: RoundedOutlinedBorder(
        clip: true,
        child: Row(
          children: [
            _SimpleOpenSaveButton(
              icon: Icons.file_upload,
              tooltip: 'Open a file that was previously saved from DevTools',
              roundedLeftBorder: true,
              roundedRightBorder: false,
              onPressed: () async {
                ga.select(screenId, gac.openFile);
                final importedFile = await importFileFromPicker(
                  acceptedTypes: const ['json'],
                );
                if (importedFile != null) {
                  Provider.of<ImportController>(
                    // ignore: use_build_context_synchronously, intentional use.
                    context,
                    listen: false,
                  ).importData(importedFile, expectedScreenId: screenId);
                } else {
                  notificationService.push(
                    'Something went wrong. Could not open selected file.',
                  );
                }
              },
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Theme.of(context).focusColor),
                ),
              ),
              child:
                  saveFormats.length == 1 &&
                          saveFormats.first == SaveFormat.devtools
                      ? _SimpleOpenSaveButton(
                        icon: Icons.file_download,
                        tooltip: 'Save this screen\'s data for offline viewing',
                        roundedLeftBorder: false,
                        roundedRightBorder: true,
                        onPressed:
                            onSave != null
                                ? () {
                                  ga.select(screenId, gac.saveFile);
                                  onSave!.call(SaveFormat.devtools);
                                }
                                : null,
                      )
                      : _DropdownSaveButton(
                        screenId: screenId,
                        onSave: onSave,
                        saveFormats: saveFormats,
                        gaItemForSaveFormatSelection:
                            gaItemForSaveFormatSelection,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleOpenSaveButton extends StatelessWidget {
  const _SimpleOpenSaveButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.roundedLeftBorder,
    required this.roundedRightBorder,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool roundedLeftBorder;
  final bool roundedRightBorder;

  @override
  Widget build(BuildContext context) {
    return DevToolsTooltip(
      message: tooltip,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: densePadding),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              left: roundedLeftBorder ? defaultRadius : Radius.zero,
              right: roundedRightBorder ? defaultRadius : Radius.zero,
            ),
          ),
        ),
        onPressed: onPressed,
        child: DevToolsIcon(icon: icon, size: defaultIconSize),
      ),
    );
  }
}

class _DropdownSaveButton extends StatefulWidget {
  const _DropdownSaveButton({
    required this.screenId,
    required this.onSave,
    this.saveFormats = const [SaveFormat.devtools],
    this.gaItemForSaveFormatSelection,
  });

  final String screenId;

  final void Function(SaveFormat)? onSave;

  final List<SaveFormat> saveFormats;

  final String Function(SaveFormat)? gaItemForSaveFormatSelection;

  @override
  State<_DropdownSaveButton> createState() => __DropdownSaveButtonState();
}

class __DropdownSaveButtonState extends State<_DropdownSaveButton> {
  var saveFormat = SaveFormat.devtools;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<SaveFormat>(
        value: saveFormat,
        menuWidth: SaveFormat.dropdownWidth,
        padding: const EdgeInsets.symmetric(horizontal: densePadding),
        borderRadius: const BorderRadius.only(
          topRight: defaultRadius,
          bottomRight: defaultRadius,
        ),
        onChanged: (selectedFormat) {
          final gaItem =
              widget.gaItemForSaveFormatSelection?.call(selectedFormat!) ??
              gac.saveFile;
          ga.select(widget.screenId, gaItem);
          widget.onSave!.call(selectedFormat!);
          setState(() {
            saveFormat = selectedFormat;
          });
        },
        selectedItemBuilder: (context) {
          return widget.saveFormats
              .map(
                (f) => DevToolsIcon(
                  icon: Icons.file_download,
                  size: defaultIconSize,
                ),
              )
              .toList();
        },
        items:
            widget.saveFormats
                .map(
                  (f) => DropdownMenuItem<SaveFormat>(
                    value: f,
                    child: Text(f.display),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class FileImportContainer extends StatefulWidget {
  const FileImportContainer({
    required this.instructions,
    required this.gaScreen,
    required this.gaSelectionImport,
    this.title,
    this.backgroundColor,
    this.gaSelectionAction,
    this.actionText,
    this.onAction,
    this.onFileSelected,
    this.onFileCleared,
    this.extensions = const ['json'],
    super.key,
  });

  final String? title;

  final Color? backgroundColor;

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
    final backgroundColor = widget.backgroundColor;

    Widget child = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (title != null) ...[
          Text(title, style: TextStyle(fontSize: scaleByFontFactor(18.0))),
          const SizedBox(height: extraLargeSpacing),
        ],
        CenteredMessage(message: widget.instructions),
        const SizedBox(height: denseSpacing),
        _buildImportFileRow(),
        if (widget.actionText != null && widget.onAction != null)
          _buildActionButton(),
      ],
    );

    if (backgroundColor != null) {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Container(
            margin: const EdgeInsets.all(extraLargeSpacing),
            padding: const EdgeInsets.all(defaultSpacing),
            decoration: BoxDecoration(
              borderRadius: defaultBorderRadius,
              color: backgroundColor,
            ),
            child: child,
          ),
        ],
      );
    }
    return Column(
      children: [
        Expanded(
          // TODO(kenz): improve drag over highlight.
          child: DragAndDrop(handleDrop: _handleImportedFile, child: child),
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
        if (importedFile != null)
          InputDecorationSuffixButton.clear(onPressed: _clearFile),
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
              onPressed:
                  importedFile != null
                      ? () => widget.onAction!(importedFile!)
                      : null,
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _importFile() async {
    final importedFile = await importFileFromPicker(
      acceptedTypes: widget.extensions,
    );
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
  return await toDevToolsFile(file);
}

Future<List<XFile>> importRawFilesFromPicker({
  List<String>? acceptedTypes,
}) async {
  final acceptedTypeGroups = [XTypeGroup(extensions: acceptedTypes)];
  return await openFiles(acceptedTypeGroups: acceptedTypeGroups);
}

@visibleForTesting
Future<DevToolsJsonFile> toDevToolsFile(XFile file) async {
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
  )
  onAction;

  @override
  State<DualFileImportContainer> createState() =>
      _DualFileImportContainerState();
}

class _DualFileImportContainerState extends State<DualFileImportContainer> {
  DevToolsJsonFile? firstImportedFile;
  DevToolsJsonFile? secondImportedFile;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = Theme.of(context).colorScheme.surface.brighten();
    return Row(
      children: [
        Expanded(
          child: FileImportContainer(
            title: widget.firstFileTitle,
            backgroundColor: backgroundColor,
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
            backgroundColor: backgroundColor,
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
              onPressed:
                  firstImportedFile != null && secondImportedFile != null
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
