import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/theme.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

class CallStack extends StatefulWidget {
  const CallStack({Key key}) : super(key: key);

  @override
  _CallStackState createState() => _CallStackState();
}

class _CallStackState extends State<CallStack> {
  DebuggerController controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;
    controller = newController;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<StackFrameAndSourcePosition>>(
      valueListenable: controller.stackFramesWithLocation,
      builder: (context, stackFrames, _) {
        return ValueListenableBuilder<StackFrameAndSourcePosition>(
          valueListenable: controller.selectedStackFrame,
          builder: (context, selectedFrame, _) {
            return ListView.builder(
              itemCount: stackFrames.length,
              itemExtent: defaultListItemHeight,
              itemBuilder: (_, index) {
                final frame = stackFrames[index];
                final selected =
                    selectedFrame == null ? index == 0 : frame == selectedFrame;
                return _buildStackFrame(frame, selected);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStackFrame(
    StackFrameAndSourcePosition frame,
    bool selected,
  ) {
    final theme = Theme.of(context);

    final regularStyle = TextStyle(color: theme.textTheme.bodyText2.color);
    final subtleStyle = TextStyle(color: theme.unselectedWidgetColor);
    final selectedStyle = TextStyle(color: theme.textSelectionColor);

    return Material(
      color: selected ? theme.selectedRowColor : null,
      child: InkWell(
        onTap: () => _onStackFrameSelected(frame),
        child: Container(
          padding: const EdgeInsets.all(densePadding),
          alignment: Alignment.centerLeft,
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              text: _descriptionFor(frame),
              style: selected ? selectedStyle : regularStyle,
              children: [
                TextSpan(
                  text: ' (${frame.scriptUri}:${frame.line})',
                  style: selected ? selectedStyle : subtleStyle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onStackFrameSelected(StackFrameAndSourcePosition frame) async {
    controller.selectStackFrame(frame);

    // TODO(kenz): Change the line selection in the code view as well.
    // TODO(kenz): consider un-selecting the selected breakpoint here.
    if (frame.script != null) {
      await controller.selectScript(frame.script);
    } else if (frame.scriptUri != null) {
      await controller
          .selectScript(controller.scriptRefForUri(frame.scriptUri));
    }
  }

  String _descriptionFor(StackFrameAndSourcePosition frame) {
    var name = frame.frame.code?.name ?? '<none>';
    if (name.startsWith('[Unoptimized] ')) {
      name = name.substring('[Unoptimized] '.length);
    }
    name = name.replaceAll('<anonymous closure>', '<closure>');

    if (frame.frame.kind == FrameKind.kAsyncSuspensionMarker) {
      name = '<async break>';
    }
    return name;
  }
}
