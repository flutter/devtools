// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/common_widgets.dart';
import '../../shared/theme.dart';
import 'debugger_controller.dart';
import 'debugger_model.dart';

class CallStack extends StatefulWidget {
  const CallStack({Key? key}) : super(key: key);

  @override
  _CallStackState createState() => _CallStackState();
}

class _CallStackState extends State<CallStack> {
  DebuggerController get controller => _controller!;
  DebuggerController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newController = Provider.of<DebuggerController>(context);
    if (newController == controller) return;

    _controller = newController;
  }

  @override
  Widget build(BuildContext context) {
    return DualValueListenableBuilder<List<StackFrameAndSourcePosition>,
        StackFrameAndSourcePosition?>(
      firstListenable: controller.stackFramesWithLocation,
      secondListenable: controller.selectedStackFrame,
      builder: (context, stackFrames, selectedFrame, _) {
        return ListView.builder(
          itemCount: stackFrames.length,
          itemExtent: defaultListItemHeight,
          itemBuilder: (_, index) {
            final frame = stackFrames[index];
            return _buildStackFrame(frame, frame == selectedFrame);
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

    Widget child;

    final asyncMarker = frame.frame.kind == FrameKind.kAsyncSuspensionMarker;
    final asyncFrame = frame.frame.kind == FrameKind.kAsyncActivation ||
        frame.frame.kind == FrameKind.kAsyncSuspensionMarker;
    final noLineInfo = frame.line == null;

    final frameDescription = frame.description;
    final locationDescription = frame.location;

    if (asyncMarker) {
      child = Row(
        children: [
          const SizedBox(width: defaultSpacing, child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: densePadding),
            child: Text(
              frameDescription,
              style: selected ? theme.selectedTextStyle : theme.subtleTextStyle,
            ),
          ),
          const Expanded(child: Divider()),
        ],
      );
    } else {
      child = RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          text: frameDescription,
          style: selected
              ? theme.selectedTextStyle
              : (asyncFrame || noLineInfo
                  ? theme.subtleTextStyle
                  : theme.regularTextStyle),
          children: [
            TextSpan(
              text: ' $locationDescription',
              style: selected ? theme.selectedTextStyle : theme.subtleTextStyle,
            ),
          ],
        ),
      );
    }

    final isAsyncBreak = frame.frame.kind == FrameKind.kAsyncSuspensionMarker;

    final result = Material(
      color: selected ? theme.selectedRowColor : null,
      child: InkWell(
        onTap: () => _onStackFrameSelected(frame),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: densePadding),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );

    if (isAsyncBreak) {
      return result;
    } else {
      return DevToolsTooltip(
        message: locationDescription == null
            ? frameDescription
            : '$frameDescription $locationDescription',
        waitDuration: tooltipWaitLong,
        child: result,
      );
    }
  }

  Future<void> _onStackFrameSelected(StackFrameAndSourcePosition frame) async {
    controller.selectStackFrame(frame);
  }
}
