// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/editor/api_classes.dart';
import 'property_editor_controller.dart';
import 'property_editor_types.dart';

/// Widget for displaying the available "Wrap with" refactors.
///
/// Each refactor is  in a [_WrapWithButton].
class WrapWithRefactors extends StatefulWidget {
  const WrapWithRefactors({
    required this.refactors,
    required this.controller,
    super.key,
  });

  final List<WrapWithRefactorAction> refactors;
  final PropertyEditorController controller;

  @override
  State<WrapWithRefactors> createState() => _RefactorsState();
}

class _RefactorsState extends State<WrapWithRefactors> {
  final _mainRefactorsGroup = <WrapWithRefactorAction>[];
  final _otherRefactorsGroup = <WrapWithRefactorAction>[];

  @override
  void initState() {
    super.initState();
    _categorizeAndSortRefactors();
  }

  @override
  void didUpdateWidget(covariant WrapWithRefactors oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refactors != oldWidget.refactors) {
      _categorizeAndSortRefactors();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showMainRefactors = _mainRefactorsGroup.isNotEmpty;
    final showOtherRefactors = _otherRefactorsGroup.isNotEmpty;
    final executeCommand = widget.controller.executeCommand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(densePadding),
          child: Text('Wrap with:'),
        ),
        if (showMainRefactors)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final refactor in _mainRefactorsGroup)
                _WrapWithButton(
                  refactor,
                  executeCommand: executeCommand,
                  iconOnly: true,
                ),
            ],
          ),
        if (showOtherRefactors)
          Padding(
            padding: const EdgeInsets.all(densePadding),
            child: _WrapWithDropdown(
              placeholderText: showMainRefactors
                  ? 'More widgets...'
                  : 'Select widget',
              refactors: _otherRefactorsGroup,
              executeCommand: executeCommand,
            ),
          ),
        const PaddedDivider.noPadding(),
      ],
    );
  }

  void _categorizeAndSortRefactors() {
    _mainRefactorsGroup.clear();
    _otherRefactorsGroup.clear();
    for (final refactor in widget.refactors) {
      final category = _mainRefactors.contains(refactor.label)
          ? _mainRefactorsGroup
          : _otherRefactorsGroup;
      category.add(refactor);
    }
    // Sort the refactors to match the order in the _mainRefactors set.
    final mainRefactorsOrder = _mainRefactors.toList();
    _mainRefactorsGroup.sort((a, b) {
      return mainRefactorsOrder
          .indexOf(a.label)
          .compareTo(mainRefactorsOrder.indexOf(b.label));
    });
  }
}

/// Dropdown button for any available refactors not in [_mainRefactors].
class _WrapWithDropdown extends StatelessWidget {
  const _WrapWithDropdown({
    required this.placeholderText,
    required this.refactors,
    required this.executeCommand,
  });

  final String placeholderText;
  final List<WrapWithRefactorAction> refactors;
  final ExecuteCommandFunction executeCommand;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<WrapWithRefactorAction>(
      hint: Text(placeholderText),
      underline:
          const SizedBox.shrink(), // Hide the default underline, UI looks cluttered with it.
      isDense: true,
      items: refactors
          .map(
            (refactor) => DropdownMenuItem<WrapWithRefactorAction>(
              value: refactor,
              child: Text(refactor.label),
            ),
          )
          .toList(),
      onChanged: (WrapWithRefactorAction? refactor) async {
        if (refactor != null) {
          await executeCommand(
            commandName: refactor.command,
            commandArgs: refactor.args,
          );
        }
      },
    );
  }
}

/// A button which triggers a single "Wrap with" refactor.
///
/// Buttons for refactors in [_refactorsWithIconAsset] have an icon.
class _WrapWithButton extends StatelessWidget {
  const _WrapWithButton(
    this.refactor, {
    required this.executeCommand,
    required this.iconOnly,
  });

  final WrapWithRefactorAction refactor;
  final ExecuteCommandFunction executeCommand;
  final bool iconOnly;

  static const _iconAssetPath = 'icons/property_editor/';

  String? _iconAsset({bool darkMode = false}) {
    if (!_refactorsWithIconAsset.contains(refactor.label)) {
      return null;
    }

    final path = '$_iconAssetPath${refactor.label.toLowerCase()}';
    return '${path}_${darkMode ? 'dark' : 'light'}_theme.png';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconAsset = _iconAsset(darkMode: theme.isDarkTheme);

    final button = OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
        side: BorderSide(
          color: iconOnly ? Colors.transparent : theme.colorScheme.onSurface,
        ),
        padding: const EdgeInsets.all(densePadding),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: iconAsset != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset(iconAsset, height: actionsIconSize),
              ],
            )
          : _buttonText(theme: theme),
      onPressed: () async {
        await executeCommand(
          commandName: refactor.command,
          commandArgs: refactor.args,
        );
      },
    );

    return Padding(
      padding: EdgeInsets.all(iconOnly ? densePadding / 2 : densePadding),
      child: iconOnly
          ? DevToolsTooltip(message: refactor.label, child: button)
          : button,
    );
  }

  Text _buttonText({required ThemeData theme}) {
    final label = refactor.label;
    // Show the first letter of the label as the icon.
    if (_refactorsWithLetterIcon.contains(label)) {
      return Text(
        label[0],
        style: theme.regularTextStyle.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: unscaledExtraLargeFontSize,
          color: theme.isDarkTheme ? Colors.white : Colors.black,
        ),
      );
    }

    return Text(label, style: theme.regularTextStyle);
  }
}

const _wrapWithPadding = 'Padding';
const _wrapWithContainer = 'Container';
const _wrapWithColumn = 'Column';
const _wrapWithRow = 'Row';
const _wrapWithCenter = 'Center';
const _wrapWithSizedBox = 'SizedBox';
const _wrapWithWidget = 'Widget';

const _refactorsWithIconAsset = {
  _wrapWithPadding,
  _wrapWithContainer,
  _wrapWithColumn,
  _wrapWithRow,
  _wrapWithCenter,
  _wrapWithSizedBox,
};

const _refactorsWithLetterIcon = {_wrapWithWidget};

const _mainRefactors = {
  ..._refactorsWithLetterIcon,
  ..._refactorsWithIconAsset,
};
