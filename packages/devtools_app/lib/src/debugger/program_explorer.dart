// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart' hide Stack;

import '../common_widgets.dart';
import '../flex_split_column.dart';
import '../globals.dart';
import '../theme.dart';
import '../tree.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'program_explorer_controller.dart';
import 'program_explorer_model.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_drive_file;
const listItemHeight = 40.0;

double get _programExplorerRowHeight => scaleByFontFactor(22.0);

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

class _FileExplorer extends StatelessWidget {
  const _FileExplorer({
    @required this.controller,
    @required this.onItemSelected,
    @required this.onItemExpanded,
  });

  final ProgramExplorerController controller;
  final Function(VMServiceObjectNode) onItemSelected;
  final Function(VMServiceObjectNode) onItemExpanded;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<VMServiceObjectNode>>(
      valueListenable: controller.rootObjectNodes,
      builder: (context, nodes, _) {
        return TreeView<VMServiceObjectNode>(
          itemExtent: _programExplorerRowHeight,
          dataRoots: nodes,
          onItemSelected: onItemSelected,
          onItemExpanded: onItemExpanded,
          dataDisplayProvider: (node, onTap) {
            return _ProgramExplorerRow(
              controller: controller,
              node: node,
              onTap: () {
                controller.selectNode(node);
                onTap();
              },
            );
          },
        );
      },
    );
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
        return ValueListenableBuilder<List<VMServiceObjectNode>>(
          valueListenable: controller.outlineNodes,
          builder: (context, nodes, _) {
            if (nodes == null || nodes.isEmpty) {
              return const Center(
                child: Text('Nothing to inspect'),
              );
            }
            return TreeView<VMServiceObjectNode>(
              itemExtent: _programExplorerRowHeight,
              dataRoots: nodes,
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
            );
          },
        );
      },
    );
  }
}

/// Picker that displays the program's structure, allowing for navigation and
/// filtering.
class ProgramExplorer extends StatelessWidget {
  ProgramExplorer({
    Key key,
    @required this.debugController,
    @required this.onSelected,
  })  : controller = debugController.programExplorerController,
        super(key: key);

  final ProgramExplorerController controller;
  final DebuggerController debugController;
  final void Function(ScriptLocation) onSelected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.initialized,
      builder: (context, initialized, _) {
        Widget body;
        if (!initialized) {
          body = const CenteredCircularProgressIndicator();
        } else {
          const fileExplorerHeader = AreaPaneHeader(
            title: Text('File Explorer'),
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
                      headers: const <PreferredSizeWidget>[
                        fileExplorerHeader,
                        AreaPaneHeader(title: Text('Outline')),
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

    onSelected(node.location);
  }

  void onItemExpanded(VMServiceObjectNode node) async {
    if (node.object != null && node.object is! Obj) {
      await controller.populateNode(node);
    }
  }
}
