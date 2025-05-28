// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/editor/api_classes.dart';
import 'property_editor_common.dart';
import 'property_editor_controller.dart';

typedef ExecuteCommandFunction =
    Future<GenericApiResponse?> Function(CodeActionCommand refactor);

/// Widget for displaying the available refactors.
///
/// Each refactor is  in a [_RefactorButton].
class Refactors extends StatefulWidget {
  const Refactors({
    required this.refactors,
    required this.controller,
    super.key,
  });

  final List<CodeActionCommand> refactors;
  final PropertyEditorController controller;

  @override
  State<Refactors> createState() => _RefactorsState();
}

class _RefactorsState extends State<Refactors> {
  final _mainRefactorsGroup = <CodeActionCommand>[];
  final _otherRefactorsGroup = <CodeActionCommand>[];

  bool _showAllRefactors = false;

  @override
  void initState() {
    super.initState();
    _categorizeRefactors();
  }

  @override
  void didUpdateWidget(covariant Refactors oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refactors != oldWidget.refactors) {
      _categorizeRefactors();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(densePadding),
          child: Text('Wrap with:'),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final refactor in _mainRefactorsGroup)
              _RefactorButton(
                refactor,
                executeCommand: widget.controller.executeCommand,
                iconOnly: true,
              ),
          ],
        ),
        if (_showAllRefactors)
          Padding(
            padding: const EdgeInsets.only(top: densePadding / 2),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final refactor in _otherRefactorsGroup)
                  _RefactorButton(
                    refactor,
                    executeCommand: widget.controller.executeCommand,
                    iconOnly: false,
                  ),
              ],
            ),
          ),
        if (_otherRefactorsGroup.isNotEmpty)
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(densePadding),
                child: ExpandableTextButton(
                  isExpanded: _showAllRefactors,
                  onTap: () {
                    setState(() {
                      _showAllRefactors = !_showAllRefactors;
                    });
                  },
                ),
              ),
            ],
          ),
        const PaddedDivider.noPadding(),
      ],
    );
  }

  void _categorizeRefactors() {
    _mainRefactorsGroup.clear();
    _otherRefactorsGroup.clear();
    for (final refactor in widget.refactors) {
      // Ignore any unexpected refactors that don't begin with "Wrap with".
      if (!refactor.title.startsWith('Wrap with')) continue;

      final category = _mainRefactors.contains(refactor.title)
          ? _mainRefactorsGroup
          : _otherRefactorsGroup;
      category.add(refactor);
    }
  }
}

/// A button which triggers a single refactor.
///
/// Buttons for refactors in [_refactorsWithIconAsset] have an icon.
class _RefactorButton extends StatelessWidget {
  const _RefactorButton(
    this.action, {
    required this.executeCommand,
    required this.iconOnly,
  });

  final CodeActionCommand action;
  final ExecuteCommandFunction executeCommand;
  final bool iconOnly;

  static const _iconAssetPath = 'icons/property_editor/';

  String get label {
    final wrapperName = action.title.split('Wrap with ').last;
    return wrapperName == 'widget...' ? 'Widget' : wrapperName;
  }

  String get command => action.command;

  String? _iconAsset({bool darkMode = false}) {
    if (!_refactorsWithIconAsset.contains(action.title)) {
      return null;
    }

    final path = '$_iconAssetPath${label.toLowerCase()}';
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
          : _buttonText(label, theme: theme),
      onPressed: () async {
        await executeCommand(action);
      },
    );

    return Padding(
      padding: EdgeInsets.all(iconOnly ? densePadding / 2 : densePadding),
      child: iconOnly ? DevToolsTooltip(message: label, child: button) : button,
    );
  }

  Text _buttonText(String label, {required ThemeData theme}) {
    // Show the first letter of the label as the icon.
    if (_refactorsWithLetterIcon.contains(action.title)) {
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

const _wrapWithPadding = 'Wrap with Padding';
const _wrapWithContainer = 'Wrap with Container';
const _wrapWithColumn = 'Wrap with Column';
const _wrapWithRow = 'Wrap with Row';
const _wrapWithCenter = 'Wrap with Center';
const _wrapWithSizedBox = 'Wrap with SizedBox';
const _wrapWithWidget = 'Wrap with widget...';

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
  ..._refactorsWithIconAsset,
  ..._refactorsWithLetterIcon,
};
