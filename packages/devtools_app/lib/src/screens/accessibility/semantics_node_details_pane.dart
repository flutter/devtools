// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:ui' show SemanticsFlag;

import 'package:devtools_app_shared/ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import 'accessibility_controller.dart';
import 'semantics_node_model.dart';

/// A pane that displays the details of the currently selected semantics node.
class SemanticsNodeDetailsPane extends StatelessWidget {
  const SemanticsNodeDetailsPane({super.key});

  static const _paneTitle = 'Semantics Node Details';
  static const _emptyMessage =
      'Select a node in the semantics tree to view its details.';

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<AccessibilityController>();
    return DevToolsAreaPane(
      header: const AreaPaneHeader(
        title: Text(_paneTitle),
        roundedTopBorder: false,
        includeTopBorder: false,
      ),
      child: ValueListenableBuilder<SemanticsNodeModel?>(
        valueListenable: controller.selectedSemanticsNode,
        builder: (context, selectedNode, _) {
          if (selectedNode == null) {
            return const CenteredMessage(message: _emptyMessage);
          }
          return _SemanticsNodeDetailsContent(node: selectedNode);
        },
      ),
    );
  }
}

/// Displays the properties and flags of a selected [SemanticsNodeModel].
class _SemanticsNodeDetailsContent extends StatelessWidget {
  const _SemanticsNodeDetailsContent({required this.node});

  final SemanticsNodeModel node;

  static const _labelTitle = 'label';
  static const _labelDescription = 'The screen reader announcement text.';

  static const _valueTitle = 'value';
  static const _valueDescription =
      'The current value of a progress indicator, slider, etc.';

  static const _hintTitle = 'hint';
  static const _hintDescription =
      'A brief description of the action that will occur.';

  static const _rectTitle = 'rect';
  static const _rectDescription =
      'The bounding box of the node in logical pixels.';

  static const _flagsTitle = 'Flags';
  static const _flagsDescription =
      'Boolean flags that dictate the semantics behavior.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SemanticsNode #${node.id}', style: theme.boldTextStyle),
            const SizedBox(height: denseSpacing),
            const Divider(),
            const SizedBox(height: denseSpacing),
            _NodeDetailSection(
              title: _labelTitle,
              description: _labelDescription,
              child: _NodeDetailValueBox(
                text: node.label,
                highlightText: true,
                wrapInQuotes: true,
              ),
            ),
            const SizedBox(height: defaultSpacing),
            _NodeDetailSection(
              title: _valueTitle,
              description: _valueDescription,
              child: _NodeDetailValueBox(text: node.value, wrapInQuotes: true),
            ),
            const SizedBox(height: defaultSpacing),
            _NodeDetailSection(
              title: _hintTitle,
              description: _hintDescription,
              child: _NodeDetailValueBox(text: node.hint, wrapInQuotes: true),
            ),
            const SizedBox(height: defaultSpacing),
            _NodeDetailSection(
              title: _rectTitle,
              description: _rectDescription,
              child: _NodeDetailValueBox(text: node.rectDisplay),
            ),
            const SizedBox(height: defaultSpacing),
            _NodeDetailSection(
              title: _flagsTitle,
              description: _flagsDescription,
              child: node.flags.isEmpty
                  ? const _NodeDetailValueBox(text: null)
                  : _SemanticsFlagsWrap(flags: node.flags),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labeled section in the node details view with a title, description, and content.
class _NodeDetailSection extends StatelessWidget {
  const _NodeDetailSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.boldTextStyle),
        const SizedBox(height: densePadding),
        Text(description, style: theme.subtleTextStyle),
        const SizedBox(height: denseSpacing),
        child,
      ],
    );
  }
}

/// A bordered container that displays a property value or `(empty)` if none is present.
class _NodeDetailValueBox extends StatelessWidget {
  const _NodeDetailValueBox({
    required this.text,
    this.highlightText = false,
    this.wrapInQuotes = false,
  });

  final String? text;
  final bool highlightText;
  final bool wrapInQuotes;

  static const _emptyPlaceholder = '(empty)';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasValue = text != null && text!.isNotEmpty;
    final displayText = hasValue
        ? (wrapInQuotes ? '"$text"' : text!)
        : _emptyPlaceholder;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(defaultSpacing),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: defaultBorderRadius,
        border: Border.all(
          color: highlightText && hasValue
              ? colorScheme.primary.withValues(alpha: 0.5)
              : theme.focusColor,
        ),
      ),
      child: SelectableText(
        displayText,
        style: _textStyle(theme, hasValue: hasValue),
      ),
    );
  }

  TextStyle _textStyle(ThemeData theme, {required bool hasValue}) {
    if (!hasValue) {
      return theme.subtleFixedFontStyle;
    }
    if (highlightText) {
      return theme.fixedFontStyle.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      );
    }
    return theme.fixedFontStyle;
  }
}

/// A wrapping layout of chips representing active [SemanticsFlag]s on a node.
class _SemanticsFlagsWrap extends StatelessWidget {
  const _SemanticsFlagsWrap({required this.flags});

  final Set<SemanticsFlag> flags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: denseSpacing,
      runSpacing: denseSpacing,
      children: [for (final flag in flags) _SemanticsFlagChip(flag: flag)],
    );
  }
}

/// A chip widget displaying the name of a single [SemanticsFlag].
class _SemanticsFlagChip extends StatelessWidget {
  const _SemanticsFlagChip({required this.flag});

  final SemanticsFlag flag;

  static const _chipBorderRadius = 4.0;
  static const _chipBackgroundAlpha = 0.12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: denseSpacing,
        vertical: densePadding,
      ),
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: _chipBackgroundAlpha),
        borderRadius: BorderRadius.circular(_chipBorderRadius),
      ),
      child: Text(flag.name, style: theme.fixedFontStyle),
    );
  }
}
