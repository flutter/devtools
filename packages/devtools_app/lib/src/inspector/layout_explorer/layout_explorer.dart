import 'package:flutter/widgets.dart';

import '../diagnostics_node.dart';
import '../inspector_controller.dart';
import 'flex/flex.dart';

/// Tab that acts as a proxy to decide which widget to be displayed
class LayoutExplorerTab extends StatefulWidget {
  const LayoutExplorerTab({Key key, this.controller}) : super(key: key);

  final InspectorController controller;

  @override
  _LayoutExplorerTabState createState() => _LayoutExplorerTabState();
}

class _LayoutExplorerTabState extends State<LayoutExplorerTab>
    with AutomaticKeepAliveClientMixin<LayoutExplorerTab> {
  InspectorController get controller => widget.controller;

  RemoteDiagnosticsNode get selected => controller?.selectedNode?.diagnostic;

  RemoteDiagnosticsNode previousSelection;

  Widget rootWidget(RemoteDiagnosticsNode node) {
    if (FlexLayoutExplorerWidget.shouldDisplay(node))
      return FlexLayoutExplorerWidget(controller);
    return const Center(
      child: Text(
        'Currently, Layout Explorer only supports Flex-based widgets'
        ' (e.g., Row, Column, Flex) or their direct children.',
        textAlign: TextAlign.center,
        overflow: TextOverflow.clip,
      ),
    );
  }

  void onSelectionChanged() {
    if (rootWidget(previousSelection).runtimeType !=
        rootWidget(selected).runtimeType) {
      setState(() => previousSelection = selected);
    }
  }

  @override
  void initState() {
    super.initState();
    controller.addSelectionListener(onSelectionChanged);
  }

  @override
  void dispose() {
    controller.removeSelectionListener(onSelectionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return rootWidget(selected);
  }

  @override
  bool get wantKeepAlive => true;
}
