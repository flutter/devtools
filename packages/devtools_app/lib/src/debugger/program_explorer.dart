// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../config_specific/host_platform/host_platform.dart';
import '../theme.dart';
import '../tree.dart';
import '../utils.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';
import 'debugger_screen.dart';
import 'program_explorer_controller.dart';
import 'program_explorer_model.dart';

const containerIcon = Icons.folder;
const libraryIcon = Icons.insert_chart;
const listItemHeight = 40.0;

class _ProgramExplorerHeader extends StatelessWidget {
  const _ProgramExplorerHeader({
    this.controller,
    this.libraryFilterFocusNode,
    this.filterController,
  });

  final ProgramExplorerController controller;
  final FocusNode libraryFilterFocusNode;
  final TextEditingController filterController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMacOS = HostPlatform.instance.isMacOS;
    final filterKey = focusLibraryFilterKeySet.describeKeys(isMacOS: isMacOS);

    return Column(
      children: [
        AreaPaneHeader(
          title: const Text('Program Explorer'),
          needsTopBorder: false,
          rightActions: [
            ValueListenableBuilder(
              valueListenable: controller.filteredObjectCount,
              builder: (context, filteredCount, _) {
                return ValueListenableBuilder(
                  valueListenable: controller.objectCount,
                  builder: (context, count, _) {
                    return CountBadge(
                      filteredItemsLength: filteredCount,
                      itemsLength: count,
                    );
                  },
                );
              },
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.focusColor),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(denseSpacing),
            child: SizedBox(
              height: defaultTextFieldHeight,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Filter ($filterKey)',
                  border: const OutlineInputBorder(),
                ),
                controller: filterController,
                onChanged: (_) {
                  final filterText = filterController.text.trim().toLowerCase();
                  controller.updateVisibleNodes(filterText);
                },
                style: theme.textTheme.bodyText2,
                focusNode: libraryFilterFocusNode,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
    final colorScheme = theme.colorScheme;

    Color iconColor = colorScheme.functionSyntaxColor;
    IconData icon = containerIcon;
    String subtext;
    String toolTip;

    if (node.object is ClassRef) {
      final clazz = node.object as ClassRef;
      icon = Icons.class_;
      iconColor = colorScheme.declarationsSyntaxColor;
      toolTip = 'class ${clazz.name}';
      if (clazz.typeParameters != null) {
        toolTip +=
            '<' + clazz.typeParameters.map((e) => e.name).join(', ') + '>';
      }
      subtext = toolTip;
    } else if (node.object is Func) {
      final func = node.object as Func;
      icon = Icons.functions;
      iconColor = colorScheme.functionSyntaxColor;
      final isInstanceMethod = func.owner is ClassRef;
      subtext = _buildFunctionTypeText(
        func.name,
        func.signature,
        isInstanceMethod: isInstanceMethod,
      );
      toolTip = '${func.name}$subtext';
    } else if (node.object is Field) {
      final field = node.object as Field;
      icon = Icons.equalizer;
      iconColor = colorScheme.variableSyntaxColor;
      subtext = _buildFieldTypeText(field);
      toolTip = '$subtext ${field.name}';
    } else if (node.object is ScriptRef || node.script != null) {
      icon = libraryIcon;
      iconColor = colorScheme.stringSyntaxColor;
      if (node.script != null) {
        subtext = node.script.uri;
        toolTip = subtext;
      }
    }

    return Tooltip(
      waitDuration: tooltipWait,
      preferBelow: false,
      message: toolTip ?? node.name,
      textStyle: theme.toolTipFixedFontStyle,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            onTap();
            controller.selectNode(node);
          },
          child: Row(
            children: [
              Icon(
                icon,
                size: defaultIconSize,
                color: iconColor,
              ),
              const SizedBox(width: densePadding),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.fixedFontStyle,
                    ),
                    if (subtext != null)
                      Text(
                        subtext,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.subtleFixedFontStyle,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    buffer.write(field.declaredType.name);
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
    buffer.write(') -> ');
    if (signature.returnType.name == null) {
      buffer.write(_buildFunctionTypeText('Function', signature.returnType));
    } else {
      buffer.write(signature.returnType.name);
    }

    return buffer.toString();
  }
}

/// Picker that displays the program's structure, allowing for navigation and
/// filtering.
class ProgramExplorer extends StatefulWidget {
  const ProgramExplorer({
    Key key,
    @required this.onSelected,
    @required this.libraryFilterFocusNode,
  }) : super(key: key);

  final void Function(ScriptLocation) onSelected;
  final FocusNode libraryFilterFocusNode;

  @override
  ProgramExplorerState createState() => ProgramExplorerState();
}

class ProgramExplorerState extends State<ProgramExplorer> {
  // TODO(devoncarew): How to retain the filter text state?
  final _filterController = TextEditingController();
  ProgramExplorerController controller;
  DebuggerController debugController;

  final _maxAutoExpandChildCount = 20;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugController = Provider.of<DebuggerController>(context);
    controller = Provider.of<ProgramExplorerController>(context);
  }

  @override
  void didUpdateWidget(ProgramExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugController = Provider.of<DebuggerController>(context);
    controller = Provider.of<ProgramExplorerController>(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.initialized,
      builder: (context, initialized, _) {
        Widget body;
        if (!initialized) {
          body = const Expanded(
            child: CenteredCircularProgressIndicator(),
          );
        } else {
          body = Expanded(
            child: ValueListenableBuilder<List<VMServiceObjectNode>>(
              valueListenable: controller.rootObjectNodes,
              builder: (context, nodes, _) {
                return TreeView<VMServiceObjectNode>(
                  onTraverse: (node) {
                    // Auto expand children when there are minimal search results.
                    if (_filterController.text.isNotEmpty &&
                        node.children.length <= _maxAutoExpandChildCount &&
                        node.object is! ClassRef) {
                      node.expand();
                    }
                  },
                  itemExtent: listItemHeight,
                  dataRoots: nodes,
                  onItemSelected: _onItemSelected,
                  onItemExpanded: _onItemExpanded,
                  dataDisplayProvider: (node, onTap) {
                    return _ProgramExplorerRow(
                      controller: controller,
                      node: node,
                      onTap: onTap,
                    );
                  },
                );
              },
            ),
          );
        }

        return OutlineDecoration(
          child: Column(
            children: [
              _ProgramExplorerHeader(
                controller: controller,
                filterController: _filterController,
                libraryFilterFocusNode: widget.libraryFilterFocusNode,
              ),
              body,
            ],
          ),
        );
      },
    );
  }

  void _onItemSelected(VMServiceObjectNode node) async {
    if (!node.isSelectable) {
      node.toggleExpansion();
      return;
    }

    if (node.object != null && node.object is! Obj) {
      await controller.populateNode(node);
    }

    // If the node is collapsed and we select it, we'll always want to expand
    // to display the children.
    if (!node.isExpanded) {
      node.expand();
    }

    ScriptRef script = node.script;
    int tokenPos = 0;
    if (node.object != null &&
        (node.object is FieldRef ||
            node.object is FuncRef ||
            node.object is ClassRef)) {
      final location = (node.object as dynamic).location;
      tokenPos = location.tokenPos;
      script = location.script;
    }

    script = await debugController.getScript(script);
    final location = tokenPos == 0
        ? null
        : SourcePosition.calculatePosition(script, tokenPos);
    widget.onSelected(
      ScriptLocation(script, location: location),
    );
  }

  void _onItemExpanded(VMServiceObjectNode node) async {
    if (node.object != null && node.object is! Obj) {
      await controller.populateNode(node);
    }
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    @required this.filteredItemsLength,
    @required this.itemsLength,
  });

  final int filteredItemsLength;
  final int itemsLength;

  @override
  Widget build(BuildContext context) {
    if (itemsLength == 0) {
      return Container();
    }
    if (filteredItemsLength == itemsLength) {
      return Badge('${nf.format(itemsLength)}');
    } else {
      return Badge('${nf.format(filteredItemsLength)} of '
          '${nf.format(itemsLength)}');
    }
  }
}
