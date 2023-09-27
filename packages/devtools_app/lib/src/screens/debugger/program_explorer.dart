// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../shared/common_widgets.dart';
import '../../shared/flex_split_column.dart';
import '../../shared/globals.dart';
import '../../shared/primitives/utils.dart';
import '../../shared/tree.dart';
import '../../shared/ui/colors.dart';
import 'program_explorer_controller.dart';
import 'program_explorer_model.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_drive_file;

double get _selectedNodeTopSpacing => defaultTreeViewRowHeight * 3;

class _ProgramExplorerRow extends StatelessWidget {
  const _ProgramExplorerRow({
    required this.node,
    this.onTap,
  });

  final VMServiceObjectNode node;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String? text = node.name;
    final toolTip = _tooltipForNode();

    if (node.object is ClassRef ||
        node.object is Func ||
        node.object is Field) {
      text = toolTip;
    }

    return DevToolsTooltip(
      message: toolTip ?? node.name,
      textStyle: theme.tooltipFixedFontStyle,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            ProgramStructureIcon(
              object: node.object,
            ),
            const SizedBox(width: densePadding),
            Flexible(
              child: Text(
                text!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.fixedFontStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _tooltipForNode() {
    String? toolTip;
    if (node.object is ClassRef) {
      final clazz = node.object as ClassRef;
      toolTip = '${clazz.name}';
      if (clazz.typeParameters != null) {
        toolTip += '<${clazz.typeParameters!.map((e) => e.name).join(', ')}>';
      }
    } else if (node.object is Func) {
      final func = node.object as Func;
      final isInstanceMethod = func.owner is ClassRef;
      final subtext = _buildFunctionTypeText(
        func.signature!,
        isInstanceMethod: isInstanceMethod,
      );
      toolTip = '${func.name}$subtext';
    } else if (node.object is Field) {
      final field = node.object as Field;
      final subtext = _buildFieldTypeText(field);
      toolTip = '$subtext${field.name}';
    } else if (node.script != null) {
      toolTip = node.script!.uri;
    }
    return toolTip;
  }

  /// Builds a string representation of a field declaration.
  ///
  /// Examples:
  ///   - final String
  ///   - static const int
  ///   - List<X0>
  String _buildFieldTypeText(Field field) {
    final buffer = StringBuffer();
    if (field.isStatic!) {
      buffer.write('static ');
    }
    if (field.isConst!) {
      buffer.write('const ');
    }
    if (field.isFinal! && !field.isConst!) {
      buffer.write('final ');
    }
    if (field.declaredType!.name != null) {
      buffer.write('${field.declaredType!.name} ');
    }
    return buffer.toString();
  }

  /// Builds a string representation of a function signature
  ///
  /// Examples:
  ///   - Foo<T>(T) -> dynamic
  ///   - Bar(String, int) -> void
  ///   - Baz(String, [int]) -> void
  ///   - Faz(String, {String? bar, required int baz}) -> int
  String _buildFunctionTypeText(
    InstanceRef signature, {
    bool isInstanceMethod = false,
  }) {
    final buffer = StringBuffer();
    if (signature.typeParameters != null) {
      final typeParams = signature.typeParameters!;
      buffer.write('<');
      for (int i = 0; i < typeParams.length; ++i) {
        buffer.write(typeParams[i].name);
        if (i + 1 != typeParams.length) {
          buffer.write(', ');
        }
      }
      buffer.write('>');
    }
    buffer.write('(');
    String? closingTag;
    final params = signature.parameters ?? [];
    for (int i = isInstanceMethod ? 1 : 0; i < params.length; ++i) {
      final param = params[i];
      if (!param.fixed! && closingTag == null) {
        if (param.name == null) {
          closingTag = ']';
          buffer.write('[');
        } else {
          closingTag = '}';
          buffer.write('{');
        }
      }
      final paramRequired = param.required;
      if (paramRequired ?? false) {
        buffer.write('required ');
      }
      final paramType = param.parameterType;
      if (paramType != null) {
        final paramTypeName = param.parameterType?.name;
        if (paramTypeName == null) {
          buffer.write(_buildFunctionTypeText(paramType));
        } else {
          buffer.write(paramTypeName);
        }
      }
      if (param.name != null) {
        buffer.write(' ${param.name}');
      }
      if (i + 1 != params.length) {
        buffer.write(', ');
      } else if (closingTag != null) {
        buffer.write(closingTag);
      }
    }
    if (kIsWeb) {
      /*
       TODO(https://github.com/flutter/devtools/issues/4039): Switch
       back to unicode arrow once supported
       */
      buffer.write(') -> ');
    } else {
      buffer.write(') → ');
    }
    final returnType = signature.returnType;
    if (returnType != null) {
      final returnTypeName = signature.returnType?.name;
      if (returnTypeName == null) {
        buffer.write(_buildFunctionTypeText(returnType));
      } else {
        buffer.write(returnTypeName);
      }
    }

    return buffer.toString();
  }
}

class ProgramStructureIcon extends StatelessWidget {
  const ProgramStructureIcon({
    super.key,
    required this.object,
  });

  final ObjRef? object;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    IconData? icon;
    String? character;
    Color color = colorScheme.functionSyntaxColor;
    bool? isShortCharacter;
    if (object is ClassRef) {
      character = 'c';
      isShortCharacter = true;
      color = colorScheme.declarationsSyntaxColor;
    } else if (object is FuncRef) {
      character = 'm';
      isShortCharacter = true;
      color = colorScheme.functionSyntaxColor;
    } else if (object is FieldRef) {
      character = 'f';
      isShortCharacter = false;
      color = colorScheme.variableSyntaxColor;
    } else if (object is LibraryRef) {
      icon = Icons.book;
      color = colorScheme.modifierSyntaxColor;
    } else if (object is ScriptRef) {
      icon = libraryIcon;
      color = colorScheme.stringSyntaxColor;
    } else if (object is CodeRef) {
      icon = Icons.code;
      color = colorScheme.controlFlowSyntaxColor;
    } else {
      icon = containerIcon;
    }

    assert(
      (icon == null && character != null && isShortCharacter != null) ||
          (icon != null && character == null && isShortCharacter == null),
    );

    return SizedBox(
      height: defaultIconSize,
      width: defaultIconSize,
      child: Container(
        decoration: icon == null
            ? BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              )
            : null,
        child: icon == null
            ? Center(
                child: Text(
                  character!,
                  style: TextStyle(
                    height: 1,
                    fontFamily: theme.fixedFontStyle.fontFamily,
                    color: theme.colorScheme.defaultBackgroundColor,
                    fontSize: smallFontSize,
                  ),
                  // Required to center the individual character within the
                  // shape. Since letters like 'm' are shorter than letters
                  // like 'f', there's padding applied to the top of shorter
                  // characters in order for everything to align properly.
                  // Since we're only dealing with individual characters, we
                  // want to disable this behavior so shorter characters don't
                  // appear to be slightly below center.
                  textHeightBehavior: TextHeightBehavior(
                    applyHeightToFirstAscent: isShortCharacter!,
                    applyHeightToLastDescent: false,
                  ),
                ),
              )
            : Icon(
                icon,
                size: defaultIconSize,
                color: color,
              ),
      ),
    );
  }
}

class _FileExplorer extends StatefulWidget {
  const _FileExplorer({
    required this.controller,
    required this.onItemSelected,
    required this.onItemExpanded,
  });

  final ProgramExplorerController controller;
  final Function(VMServiceObjectNode) onItemSelected;
  final Function(VMServiceObjectNode) onItemExpanded;

  @override
  State<_FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<_FileExplorer> with AutoDisposeMixin {
  late final ScrollController _scrollController;

  double get selectedNodeOffset => widget.controller.selectedNodeIndex.value ==
          -1
      ? -1
      : widget.controller.selectedNodeIndex.value * defaultTreeViewRowHeight;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    addAutoDisposeListener(
      widget.controller.selectedNodeIndex,
      _maybeScrollToSelectedNode,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TreeView<VMServiceObjectNode>(
      dataRootsListenable: widget.controller.rootObjectNodes,
      onItemSelected: widget.onItemSelected,
      onItemExpanded: widget.onItemExpanded,
      scrollController: _scrollController,
      includeScrollbar: true,
      dataDisplayProvider: (node, onTap) {
        return _ProgramExplorerRow(
          node: node,
          onTap: () {
            unawaited(widget.controller.selectNode(node));
            onTap();
          },
        );
      },
    );
  }

  void _maybeScrollToSelectedNode() {
    // If the node offset is invalid, don't scroll.
    if (selectedNodeOffset < 0) return;

    final extentVisible = Range(
      _scrollController.offset,
      _scrollController.offset + _scrollController.position.extentInside,
    );
    if (!extentVisible.contains(selectedNodeOffset)) {
      unawaited(
        _scrollController.animateTo(
          selectedNodeOffset - _selectedNodeTopSpacing,
          duration: longDuration,
          curve: defaultCurve,
        ),
      );
    }
  }
}

class _ProgramOutlineView extends StatelessWidget {
  const _ProgramOutlineView({
    required this.controller,
    required this.onItemSelected,
    required this.onItemExpanded,
  });

  final ProgramExplorerController controller;
  final Function(VMServiceObjectNode) onItemSelected;
  final Function(VMServiceObjectNode) onItemExpanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.isLoadingOutline,
      builder: (context, isLoadingOutline, _) {
        if (isLoadingOutline) {
          return const CenteredCircularProgressIndicator();
        }
        return TreeView<VMServiceObjectNode>(
          dataRootsListenable: controller.outlineNodes,
          onItemSelected: onItemSelected,
          onItemExpanded: onItemExpanded,
          dataDisplayProvider: (node, onTap) {
            return _ProgramExplorerRow(
              node: node,
              onTap: () async {
                await node.populateLocation();
                controller.selectOutlineNode(node);
                onTap();
              },
            );
          },
          emptyTreeViewBuilder: () => const Center(
            child: Text('Nothing to inspect'),
          ),
        );
      },
    );
  }
}

/// Picker that displays the program's structure, allowing for navigation and
/// filtering.
class ProgramExplorer extends StatelessWidget {
  const ProgramExplorer({
    super.key,
    required this.controller,
    this.title = 'File Explorer',
    this.onNodeSelected,
    this.displayHeader = true,
  });

  final ProgramExplorerController controller;
  final String title;
  final void Function(VMServiceObjectNode)? onNodeSelected;
  final bool displayHeader;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.initialized,
      builder: (context, initialized, _) {
        Widget body;
        if (!initialized) {
          body = const CenteredCircularProgressIndicator();
        } else {
          final fileExplorerHeader = displayHeader
              ? AreaPaneHeader(
                  title: Text(title),
                  includeTopBorder: false,
                  roundedTopBorder: false,
                )
              : const BlankHeader();
          final fileExplorer = _FileExplorer(
            controller: controller,
            onItemExpanded: onItemExpanded,
            onItemSelected: onItemSelected,
          );
          body = LayoutBuilder(
            builder: (context, constraints) {
              // Disable the program outline view when talking with dwds due to
              // the following bugs:
              //   - https://github.com/dart-lang/webdev/issues/1427
              //   - https://github.com/dart-lang/webdev/issues/1428
              //
              // TODO(bkonyi): enable outline view for web applications when
              // the above issues are resolved.
              //
              // See https://github.com/flutter/devtools/issues/3447.
              return serviceConnection
                      .serviceManager.connectedApp!.isDartWebAppNow!
                  ? Column(
                      children: [
                        fileExplorerHeader,
                        Expanded(child: fileExplorer),
                      ],
                    )
                  : FlexSplitColumn(
                      totalHeight: constraints.maxHeight,
                      initialFractions: const [0.7, 0.3],
                      minSizes: const [0.0, 0.0],
                      headers: <PreferredSizeWidget>[
                        fileExplorerHeader as PreferredSizeWidget,
                        const AreaPaneHeader(
                          title: Text('Outline'),
                          roundedTopBorder: false,
                        ),
                      ],
                      children: [
                        fileExplorer,
                        _ProgramOutlineView(
                          controller: controller,
                          onItemExpanded: onItemExpanded,
                          onItemSelected: onItemSelected,
                        ),
                      ],
                    );
            },
          );
        }
        return body;
      },
    );
  }

  void onItemSelected(VMServiceObjectNode node) async {
    if (!node.isSelectable) {
      node.toggleExpansion();
      return;
    }

    await node.populateLocation();

    if (node.object != null && node.object is! Obj) {
      await controller.populateNode(node);
    }

    // If the node is collapsed and we select it, we'll always want to expand
    // to display the children.
    if (!node.isExpanded) {
      node.expand();
    }

    if (onNodeSelected != null) onNodeSelected!(node);
  }

  void onItemExpanded(VMServiceObjectNode node) async {
    if (node.object != null && node.object is! Obj) {
      await controller.populateNode(node);
    }
  }
}
