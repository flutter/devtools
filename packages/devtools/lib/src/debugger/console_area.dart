// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:codemirror/codemirror.dart';
import 'package:devtools/src/ui/theme.dart';

import '../ui/elements.dart';
import '../utils.dart';

class ConsoleArea implements CoreElementView {
  ConsoleArea() {
    final Map<String, dynamic> options = <String, dynamic>{
      'mode': 'text/plain',
    };

    _container = div()
      ..layoutVertical()
      ..flex();
    _editor = CodeMirror.fromElement(_container.element, options: options);
    _editor.setReadOnly(true);
    if (isDarkTheme) {
      _editor.setTheme('zenburn');
    }

    final codeMirrorElement = _container.element.children[0];
    codeMirrorElement.setAttribute('flex', '');
  }

  final DelayedTimer _timer = DelayedTimer(
      const Duration(milliseconds: 100), const Duration(seconds: 1));
  final StringBuffer _bufferedText = StringBuffer();

  CoreElement _container;
  CodeMirror _editor;

  @override
  CoreElement get element => _container;

  void refresh() => _editor.refresh();

  void clear() {
    _editor.getDoc().setValue('');
  }

  void appendText(String text) {
    // We delay writes here to batch up calls to editor.replaceRange().
    _bufferedText.write(text);

    _timer.invoke(() {
      final String string = _bufferedText.toString();
      _bufferedText.clear();
      _append(string);
    });
  }

  void _append(String text) {
    // append text
    _editor
        .getDoc()
        .replaceRange(text, Position(_editor.getDoc().lastLine() + 1, 0));

    // scroll to end
    final int lastLineIndex = _editor.getDoc().lastLine();
    final String lastLine = _editor.getDoc().getLine(lastLineIndex);
    _editor.scrollIntoView(lastLineIndex, lastLine.length);
  }

  String getContents() {
    return _editor.getDoc().getValue();
  }
}
