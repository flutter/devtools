// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart=2.9

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../../primitives/auto_dispose_mixin.dart';
import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/flex_split_column.dart';
import '../../shared/globals.dart';
import '../../shared/theme.dart';
import '../../shared/tree.dart';
import '../../shared/utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'program_explorer_controller.dart';
import 'program_explorer_model.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_drive_file;
const listItemHeight = 40.0;

double get _programExplorerRowHeight => scaleByFontFactor(22.0);
double get _selectedNodeTopSpacing => _programExplorerRowHeight * 3;

class _ProgramExplorerRow extends StatelessWidget {
  const _ProgramExplorerRow({
    @required this.controller,
    @required this.node,
    this.onTap,
  });

  final ProgramExplorerController controller;
  final VMServiceObjectNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String text = node.name;
    final toolTip = _tooltipForNode();

    if (node.object is ClassRef ||
        node.object is Func ||
        node.object is Field) {
      text = toolTip;
    }

    return DevToolsTooltip(
      message: toolTip ?? node.name,
      textStyle: theme.toolTipFixedFontStyle,
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
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.fixedFontStyle.copyWith(
                  color: node.isSelected
                      ? Colors.white
                      : theme.fixedFontStyle.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tooltipForNode() {
    String toolTip;
    if (node.object is ClassRef) {
      final clazz = node.object as ClassRef;
      toolTip = '${clazz.name}';
      if (clazz.typeParameters != null) {
        toolTip +=
            '<' + clazz.typeParameters.map((e) => e.name).join(', ') + '>';
      }
    } else if (node.object is Func) {
      final func = node.object as Func;
      final isInstanceMethod = func.owner is ClassRef;
      final subtext = _buildFunctionTypeText(
        func.name,
        func.signature,
        isInstanceMethod: isInstanceMethod,
      );
      toolTip = '${func.name}$subtext';
    } else if (node.object is Field) {
      final field = node.object as Field;
      final subtext = _buildFieldTypeText(field);
      toolTip = '$subtext${field.name}';
    } else if (node.script != null) {
      toolTip = node.script.uri;
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
    if (field.isStatic) {
      buffer.write('static ');
    }
    if (field.isConst) {
      buffer.write('const ');
    }
    if (field.isFinal && !field.isConst) {
      buffer.write('final ');
    }
    if (field.declaredType.name != null) {
      buffer.write('${field.declaredType.name} ');
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
    String functionName,
    InstanceRef signature, {
    bool isInstanceMethod = false,
  }) {
    final buffer = StringBuffer();
    if (signature.typeParameters != null) {
      final typeParams = signature.typeParameters;
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
    String closingTag;
    for (int i = isInstanceMethod ? 1 : 0;
        i < signature.parameters.length;
        ++i) {
      final param = signature.parameters[i];
      if (!param.fixed && closingTag == null) {
        if (param.name == null) {
          closingTag = ']';
          buffer.write('[');
        } else {
          closingTag = '}';
          buffer.write('{');
        }
      }
      if (param.required != null && param.required) {
        buffer.write('required ');
      }
      if (param.parameterType.name == null) {
        buffer.write(_buildFunctionTypeText('Function', param.parameterType));
      } else {
        buffer.write(param.parameterType.name);
      }
      if (param.name != null) {
        buffer.write(' ${param.name}');
      }
      if (i + 1 != signature.parameters.length) {
        buffer.write(', ');
      } else if (closingTag != null) {
        buffer.write(closingTag);
      }
    }
    buffer.write(') → ');
    if (signature.returnType.name == null) {
      buffer.write(_buildFunctionTypeText('Function', signature.returnType));
    } else {
      buffer.write(signature.returnType.name);
    }

    return buffer.toString();
  }
}

class ProgramStructureIcon extends StatelessWidget {
  const ProgramStructureIcon({
    @required this.object,
  });

  final ObjRef object;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    IconData icon;
    String character;
    Color color = colorScheme.functionSyntaxColor;
    bool isShortCharacter;
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
    } else {
      icon = containerIcon;
    }

    assert((icon == null && character != null && isShortCharacter != null) ||
        (icon != null && character == null && isShortCharacter == null));

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
                  character,
                  style: TextStyle(
                    height: 1,
                    fontFamily: theme.fixedFontStyle.fontFamily,
                    color: theme.colorScheme.defaultBackgroundColor,
                    fontSize: chartFontSizeSmall,
                  ),
                  // Required to center the individual character within the
                  // shape. Since letters like 'm' are shorter than letters
                  // like 'f', there's padding applied to the top of shorter
                  // characters in order for everything to align properly.
                  // Since we're only dealing with individual characters, we
                  // want to disable this behavior so shorter characters don't
                  // appear to be slightly below center.
                  textHeightBehavior: TextHeightBehavior(
                    applyHeightToFirstAscent: isShortCharacter,
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
    @required this.controller,
    @required this.onItemSelected,
    @required this.onItemExpanded,
  });

  final ProgramExplorerController controller;
  final Function(VMServiceObjectNode) onItemSelected;
  final Function(VMServiceObjectNode) onItemExpanded;

  @override
  State<_FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<_FileExplorer> with AutoDisposeMixin {
  final ScrollController _scrollController = ScrollController();

  double get selectedNodeOffset => widget.controller.selectedNodeIndex.value ==
          -1
      ? -1
      : widget.controller.selectedNodeIndex.value * _programExplorerRowHeight;

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(
      widget.controller.selectedNodeIndex,
      _maybeScrollToSelectedNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      controller: _scrollController,
      child: TreeView<VMServiceObjectNode>(
        itemExtent: _programExplorerRowHeight,
        dataRootsListenable: widget.controller.rootObjectNodes,
        onItemSelected: widget.onItemSelected,
        onItemExpanded: widget.onItemExpanded,
        scrollController: _scrollController,
        dataDisplayProvider: (node, onTap) {
          return _ProgramExplorerRow(
            controller: widget.controller,
            node: node,
            onTap: () {
              widget.controller.selectNode(node);
              onTap();
            },
          );
        },
      ),
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
      _scrollController.animateTo(
        selectedNodeOffset - _selectedNodeTopSpacing,
        duration: longDuration,
        curve: defaultCurve,
      );
    }
  }
}

class _ProgramOutlineView extends StatelessWidget {
  const _ProgramOutlineView({
    @required this.controller,
    @required this.onItemSelected,
    @required this.onItemExpanded,
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
          itemExtent: _programExplorerRowHeight,
          dataRootsListenable: controller.outlineNodes,
          onItemSelected: onItemSelected,
          onItemExpanded: onItemExpanded,
          dataDisplayProvider: (node, onTap) {
            return _ProgramExplorerRow(
              controller: controller,
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
    Key key,
    @required this.controller,
    this.onSelected,
    this.title = 'File Explorer',
  })  : super(key: key);

  final ProgramExplorerController controller;
  final void Function(ScriptLocation) onSelected;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.initialized,
      builder: (context, initialized, _) {
        Widget body;
        if (!initialized) {
          body = const CenteredCircularProgressIndicator();
        } else {
          final fileExplorerHeader = AreaPaneHeader(
            title: Text(title),
            needsTopBorder: false,
          );
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
              return serviceManager.connectedApp.isDartWebAppNow
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
                        fileExplorerHeader,
                        const AreaPaneHeader(title: Text('Outline')),
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
        return OutlineDecoration(
          child: body,
        );
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

    if (onSelected != null) onSelected(node.location);
  }

  void onItemExpanded(VMServiceObjectNode node) async {
    if (node.object != null && node.object is! Obj) {
      await controller.populateNode(node);
    }
  }
}
