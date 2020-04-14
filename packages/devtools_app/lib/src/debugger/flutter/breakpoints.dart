// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../flutter/theme.dart';
import 'codeview.dart';
import 'common.dart';
import 'debugger_controller.dart';

class BreakpointPicker extends StatelessWidget {
  const BreakpointPicker({Key key, @required this.controller})
      : super(key: key);
  final DebuggerController controller;

  String textFor(Breakpoint breakpoint) {
    if (breakpoint.resolved) {
      final location = breakpoint.location as SourceLocation;
      // TODO(djshuckerow): Resolve the scripts in the background and
      // switch from token position to line numbers.
      return '${location.script.uri.split('/').last} Position '
          '${location.tokenPos} (${location.script.uri})';
    } else {
      final location = breakpoint.location as UnresolvedSourceLocation;
      return '${location.script.uri.split('/').last} Position '
          '${location.line} (${location.script.uri})';
    }
  }

  @override
  Widget build(BuildContext context) {
    return densePadding(
      Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            child: ValueListenableBuilder(
              valueListenable: controller.breakpoints,
              builder: (context, breakpoints, _) {
                return ListView.builder(
                  itemCount: breakpoints.length,
                  itemExtent: defaultListItemHeight,
                  itemBuilder: (context, index) => SizedBox(
                    height: CodeView.rowHeight,
                    child: Text(textFor(breakpoints[index])),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
