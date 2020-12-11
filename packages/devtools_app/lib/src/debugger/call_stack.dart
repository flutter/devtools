// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' hide Stack;
import 'package:provider/provider.dart';
import 'package:vm_service/vm_service.dart';

import '../common_widgets.dart';
import '../theme.dart';
import '../utils.dart';
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
    return Column(children: [
      ValueListenableBuilder<List<StackFrameAndSourcePosition>>(
          valueListenable: controller.stackFramesWithLocation,
          builder: (context, stackFrames, _) {
            return Expanded(
                child: ValueListenableBuilder<StackFrameAndSourcePosition>(
              valueListenable: controller.selectedStackFrame,
              builder: (context, selectedFrame, _) {
                return ListView.builder(
                  itemCount: stackFrames.length,
                  itemExtent: defaultListItemHeight,
                  itemBuilder: (_, index) {
                    final frame = stackFrames[index];
                    return _buildStackFrame(frame, frame == selectedFrame);
                  },
                );
              },
            ));
          }),
      ValueListenableBuilder<bool>(
          valueListenable: controller.hasTruncatedFrames,
          builder: (_, hasTruncatedFrames, __) {
            if (hasTruncatedFrames) {
              return FlatButton(
                onPressed: () => controller.getFullStack(),
                child: const Text('SHOW ALL'),
              );
            }
            return const SizedBox(height: 0, width: 0);
          })
    ]);
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

    final frameDescription = _descriptionFor(frame);
    final locationDescription = _locationFor(frame);

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
      return Tooltip(
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

  String _descriptionFor(StackFrameAndSourcePosition frame) {
    const unoptimized = '[Unoptimized] ';
    const none = '<none>';
    const anonymousClosure = '<anonymous closure>';
    const closure = '<closure>';
    const asyncBreak = '<async break>';

    if (frame.frame.kind == FrameKind.kAsyncSuspensionMarker) {
      return asyncBreak;
    }

    var name = frame.frame.code?.name ?? none;
    if (name.startsWith(unoptimized)) {
      name = name.substring(unoptimized.length);
    }
    name = name.replaceAll(anonymousClosure, closure);
    name = name == none ? name : '$name()';
    return name;
  }

  String _locationFor(StackFrameAndSourcePosition frame) {
    final uri = frame.scriptUri;
    if (uri == null) {
      return uri;
    }
    final file = uri.split('/').last;
    return frame.line == null ? file : '$file ${frame.line}';
  }
}

class CallStackCountBadge extends StatelessWidget {
  const CallStackCountBadge({@required this.stackFrames});

  final List<StackFrameAndSourcePosition> stackFrames;

  @override
  Widget build(BuildContext context) {
    return Badge('${nf.format(stackFrames.length)}');
  }
}
