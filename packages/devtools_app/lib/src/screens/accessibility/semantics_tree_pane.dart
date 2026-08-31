// Copyright 2026 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:ui' show SemanticsFlag;

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';

import '../../shared/analytics/constants.dart' as gac;
import '../../shared/globals.dart';
import '../../shared/ui/common_widgets.dart';
import '../../shared/ui/tree_view.dart';
import 'accessibility_controller.dart';

/// A pane that displays the semantics tree of the connected app.
class AccessibilitySemanticsTreePane extends StatelessWidget {
  const AccessibilitySemanticsTreePane({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = screenControllers.lookup<AccessibilityController>();
    return ValueListenableBuilder<List<SemanticsNodeModel>>(
      valueListenable: controller.semanticsRoots,
      builder: (context, roots, _) {
        return DevToolsAreaPane(
          header: AreaPaneHeader(
            title: const Text('Semantics Tree'),
            includeTopBorder: false,
            roundedTopBorder: false,
            actions: [
              if (roots.isNotEmpty)
                RefreshButton(
                  iconOnly: true,
                  tooltip: 'Refresh Semantics Tree',
                  gaScreen: gac.accessibility,
                  gaSelection: gac.refresh,
                  onPressed: controller.loadSemanticsTree,
                ),
            ],
          ),
          child: ValueListenableBuilder<bool>(
            valueListenable: controller.semanticsTreeLoading,
            builder: (context, loading, _) {
              if (loading) {
                return const CenteredCircularProgressIndicator();
              }
              return ValueListenableBuilder<String?>(
                valueListenable: controller.semanticsTreeError,
                builder: (context, error, _) {
                  if (error != null) {
                    return _SemanticsTreeErrorState(
                      errorMessage: error,
                      onRetry: controller.loadSemanticsTree,
                    );
                  }
                  if (roots.isEmpty) {
                    return _SemanticsTreeEmptyState(
                      onLoad: controller.loadSemanticsTree,
                    );
                  }
                  return _SemanticsTreeContent(controller: controller);
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _SemanticsTreeEmptyState extends StatelessWidget {
  const _SemanticsTreeEmptyState({required this.onLoad});

  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CenteredMessage(
            message:
                'No semantics tree loaded. Inspect the accessibility hierarchy of the connected app.',
          ),
          const SizedBox(height: defaultSpacing),
          DevToolsButton(
            onPressed: onLoad,
            icon: Icons.account_tree_outlined,
            label: 'Load Semantics Tree',
            elevated: true,
          ),
        ],
      ),
    );
  }
}

class _SemanticsTreeErrorState extends StatelessWidget {
  const _SemanticsTreeErrorState({
    required this.errorMessage,
    required this.onRetry,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(defaultSpacing),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SelectableText(
              errorMessage,
              style: theme.regularTextStyle.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: defaultSpacing),
            DevToolsButton(
              onPressed: onRetry,
              icon: Icons.refresh,
              label: 'Try Again',
              elevated: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SemanticsTreeContent extends StatelessWidget {
  const _SemanticsTreeContent({required this.controller});

  final AccessibilityController controller;

  static IconData _iconForNode(SemanticsNodeModel node) {
    if (node.flags.contains(SemanticsFlag.isButton)) {
      return Icons.smart_button_rounded;
    }
    if (node.flags.contains(SemanticsFlag.isTextField)) {
      return Icons.text_fields_rounded;
    }
    if (node.flags.contains(SemanticsFlag.isHeader)) {
      return Icons.title_rounded;
    }
    if (node.flags.contains(SemanticsFlag.isSlider)) {
      return Icons.linear_scale_rounded;
    }
    if (node.flags.contains(SemanticsFlag.hasCheckedState)) {
      return Icons.check_box_outlined;
    }
    return Icons.widgets_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TreeView<SemanticsNodeModel>(
      dataRootsListenable: controller.semanticsRoots,
      dataDisplayProvider: (node, onPressed) {
        return InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: denseSpacing),
            child: Row(
              children: [
                Icon(
                  _iconForNode(node),
                  size: defaultIconSize,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(width: denseSpacing),
                Text(
                  'SemanticsNode #${node.id}',
                  maxLines: 1,
                  style: theme.fixedFontStyle,
                ),
                if (node.label.isNotEmpty) ...[
                  const SizedBox(width: denseSpacing),
                  Flexible(
                    child: Text(
                      '"${node.label}"',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.subtleTextStyle.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
                if (node.widgetName.isNotEmpty) ...[
                  const SizedBox(width: denseSpacing),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: densePadding,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      node.widgetName,
                      maxLines: 1,
                      style: theme.subtleTextStyle.copyWith(
                        color: colorScheme.primary,
                        fontSize: smallFontSize,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
