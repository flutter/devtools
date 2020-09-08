// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vm_service/vm_service.dart';

import '../notifications.dart';
import 'debugger_controller.dart';

// TODO(devoncarew): We'll want some kind of code completion w/ eval.
// TODO(devoncarew): We should insert eval result objects into the console as
// expandable objects.

class ExpressionEvalField extends StatefulWidget {
  const ExpressionEvalField({
    this.controller,
  });

  final DebuggerController controller;

  @override
  _ExpressionEvalFieldState createState() => _ExpressionEvalFieldState();
}

class _ExpressionEvalFieldState extends State<ExpressionEvalField> {
  TextEditingController textController;
  FocusNode textFocus;
  int historyPosition = -1;

  @override
  void initState() {
    super.initState();

    textController = TextEditingController();
    textFocus = FocusNode();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.focusColor),
        ),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          const Text('>'),
          const SizedBox(width: 8.0),
          Expanded(
            child: Focus(
              onKey: (_, RawKeyEvent event) {
                if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
                  _historyNavUp();
                  return true;
                } else if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
                  _historyNavDown();
                  return true;
                }

                return false;
              },
              child: TextField(
                onSubmitted: (value) => _handleExpressionEval(context, value),
                focusNode: textFocus,
                decoration: null,
                controller: textController,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleExpressionEval(
    BuildContext context,
    String expressionText,
  ) async {
    textFocus.requestFocus();

    // Don't try to eval if we're not paused.
    if (!widget.controller.isPaused.value) {
      Notifications.of(context)
          .push('Application must be paused to support expression evaluation.');
      return;
    }

    expressionText = expressionText.trim();

    widget.controller.appendStdio('> $expressionText\n');
    setState(() {
      historyPosition = -1;
      widget.controller.evalHistory.pushEvalHistory(expressionText);
    });
    textController.clear();

    try {
      // Response is either a ErrorRef, InstanceRef, or Sentinel.
      final response =
          await widget.controller.evalAtCurrentFrame(expressionText);

      // Display the response to the user.
      if (response is InstanceRef) {
        final value = await _getBestStringValue(response);
        _emitToConsole(value);
      } else {
        var value = response.toString();

        if (response is ErrorRef) {
          value = response.message;
        } else if (response is Sentinel) {
          value = response.valueAsString;
        }

        _emitToConsole(value);
      }
    } catch (e) {
      // Display the error to the user.
      _emitToConsole('$e');
    }
  }

  void _emitToConsole(String text) {
    widget.controller.appendStdio('  ${text.replaceAll('\n', '\n  ')}\n');
  }

  @override
  void dispose() {
    textFocus.dispose();
    textController.dispose();
    super.dispose();
  }

  void _historyNavUp() {
    final evalHistory = widget.controller.evalHistory;
    if (!evalHistory.canNavigateUp) {
      return;
    }

    setState(() {
      evalHistory.navigateUp();

      final text = evalHistory.currentText;
      textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _historyNavDown() {
    final evalHistory = widget.controller.evalHistory;
    if (!evalHistory.canNavigateDown) {
      return;
    }

    setState(() {
      evalHistory.navigateDown();

      final text = evalHistory.currentText ?? '';
      textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  Future<String> _getBestStringValue(InstanceRef response) async {
    // Return the string value iff present and not truncated.
    // Note: [valueAsStringIsTruncated] is actually a tri-state:
    // string value is not truncated iff [valueAsStringIsTruncated]
    // is null or [valueAsStringIsTruncated] is false.
    if (response.valueAsString != null &&
        response.valueAsStringIsTruncated != true) {
      return response.valueAsString;
    }

    // Call `toString()` on the error object and display that.
    final dynamic toStringResult =
        await widget.controller.invokeToString(response);

    if (toStringResult is ErrorRef) {
      return _valueAsString(response);
    } else if (toStringResult is InstanceRef) {
      final str =
          await _retrieveFullStringValue(widget.controller, toStringResult);
      return response.kind == 'String' ? "'$str'" : str;
    } else {
      return toStringResult.toString();
    }
  }
}

String _valueAsString(InstanceRef ref) {
  if (ref == null) {
    return null;
  }

  if (ref.valueAsString == null) {
    return ref.valueAsString;
  }

  if (ref.valueAsStringIsTruncated == true) {
    return '${ref.valueAsString}...';
  } else {
    return ref.valueAsString;
  }
}

Future<String> _retrieveFullStringValue(
  DebuggerController controller,
  InstanceRef stringRef,
) {
  return controller.retrieveFullStringValue(
    stringRef,
    onUnavailable: (truncatedValue) => '${stringRef.valueAsString}...',
  );
}
