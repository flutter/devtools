// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../../shared/editor/api_classes.dart';
import 'property_editor_common.dart';
import 'property_editor_controller.dart';

/// Widget for displaying the available refactors.
///
/// Each refactor is given a [_RefactorButton].
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
  final _mainRefactors = <CodeActionCommand>[];
  final _otherRefactors = <CodeActionCommand>[];

  bool _showAllRefactors = false;

  @override
  void initState() {
    super.initState();
    _categorizeRefactors();
  }

  @override
  Widget build(BuildContext context) {
    final widgetName = widget.controller.widgetName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(densePadding),
          child: _wrapWithLabel(widgetName),
        ),

        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final refactor in _mainRefactors) _RefactorButton(refactor),
            if (_showAllRefactors)
              for (final refactor in _otherRefactors) _RefactorButton(refactor),
            if (_otherRefactors.isNotEmpty)
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
    _mainRefactors.clear();
    _otherRefactors.clear();
    for (final refactor in widget.refactors) {
      final category = _refactorsWithIconAsset.contains(refactor.title)
          ? _mainRefactors
          : _otherRefactors;
      category.add(refactor);
    }
  }

  Widget _wrapWithLabel(String? widgetName) => Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'Wrap '),
        if (widgetName != null)
          TextSpan(
            text: widgetName,
            style: Theme.of(
              context,
            ).fixedFontStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        TextSpan(text: '${widgetName != null ? ' ' : ''}with:'),
      ],
    ),
  );
}

/// A button which triggers a single refactor.
///
/// Buttons for refactors in [_refactorsWithIconAsset] have an icon.
class _RefactorButton extends StatelessWidget {
  const _RefactorButton(this.action);

  final CodeActionCommand action;

  static const _iconAssetPath = 'icons/preview/';

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
    if (darkMode) {
      return '${path}_dark.png';
    } else {
      return '$path.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconAsset = _iconAsset(darkMode: theme.isDarkTheme);

    return Padding(
      padding: const EdgeInsets.all(densePadding),
      child: OutlinedButton(
        child: iconAsset != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(iconAsset, height: actionsIconSize),
                  const SizedBox(width: denseSpacing),
                  Text(label),
                ],
              )
            : Text(label),
        onPressed: () {
          print('pressed $command');
        },
      ),
    );
  }
}

const _wrapWithPadding = 'Wrap with Padding';
const _wrapWithContainer = 'Wrap with Container';
const _wrapWithColumn = 'Wrap with Column';
const _wrapWithRow = 'Wrap with Row';
const _wrapWithCenter = 'Wrap with Center';

const _refactorsWithIconAsset = [
  _wrapWithPadding,
  _wrapWithContainer,
  _wrapWithColumn,
  _wrapWithRow,
  _wrapWithCenter,
];
