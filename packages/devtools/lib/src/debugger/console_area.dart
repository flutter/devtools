// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:ansi_up/ansi_up.dart';
import 'package:codemirror/codemirror.dart';
import 'package:devtools/src/ui/theme.dart';
import 'package:html_shim/html.dart' as html;

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
    _editor = CodeMirror.fromElement(html.toDartHtmlElement(_container.element), options: options);
    _editor.setReadOnly(true);
    if (isDarkTheme) {
      _editor.setTheme('darcula');
    }

    final codeMirrorElement = _container.element.children[0];
    codeMirrorElement.setAttribute('flex', '');
  }

  final DelayedTimer _timer = DelayedTimer(
      const Duration(milliseconds: 100), const Duration(seconds: 1));
  final StringBuffer _bufferedText = StringBuffer();

  /// Ansi terminal color code decoder.
  AnsiUp _ansiUp = AnsiUp();

  CoreElement _container;
  CodeMirror _editor;

  @override
  CoreElement get element => _container;

  void refresh() => _editor.refresh();

  void clear() {
    _editor.getDoc().setValue('');
    _ansiUp = AnsiUp();
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

  Position _documentEnd() {
    final doc = _editor.getDoc();
    final lastLine = doc.lastLine();
    return Position(lastLine, doc.getLine(lastLine).length);
  }

  void _append(String text) {
    final scrollInfo = _editor.getScrollInfo();
    // If the last line of the console is visible, after appending content we
    // should scroll so that the last line of the editor is still visible.
    // TODO(jacobr): add an optional setting to always scroll to the end of the
    // console when new content is added.
    final scrollToEnd =
        scrollInfo.top + scrollInfo.clientHeight >= scrollInfo.height;

    final chunks = decodeAnsiColorEscapeCodes(text, _ansiUp);

    final doc = _editor.getDoc();
    for (StyledText chunk in chunks) {
      final startPosition = _documentEnd();
      doc.replaceRange(chunk.text, startPosition);

      final style = chunk.style;
      if (style != null) {
        doc.markText(startPosition, _documentEnd(), css: style);
      }
    }

    if (scrollToEnd) {
      final documentEnd = _documentEnd();
      _editor.scrollIntoView(documentEnd.line, documentEnd.ch);
    }
  }

  /// Returns a visualization of the contents of the console suitable for
  /// integration tests.
  ///
  /// TextMarkers in the content are visualized with pseudo HTML+CSS to make it
  /// easy to ensure that the styling of the content matches what was expected.
  String styledContents() {
    final doc = _editor.getDoc();
    final marks = doc.getAllMarks();
    final startTags = <Position, StringBuffer>{};
    final endTags = <Position, StringBuffer>{};
    for (var mark in marks) {
      final positions = mark.find();
      assert(positions.isNotEmpty);
      final String css = mark.jsProxy['css'];
      if (css == null || css.isEmpty) continue;
      final start = positions.first;
      final end = positions.last;
      if (start.line != null && start.ch != null) {
        final startTag = startTags.putIfAbsent(start, () => StringBuffer());
        startTag.write("<span style='$css'>");
      }
      if (end.line != null && end.ch != null) {
        final endTag = endTags.putIfAbsent(end, () => StringBuffer());
        endTag.write('</span>');
      }
    }
    final sb = StringBuffer();
    for (int line = 0; line < doc.lastLine(); line++) {
      final text = doc.getLine(line);
      for (int col = 0; col < text.length; col++) {
        final position = Position(line, col);
        final startTag = startTags[position];
        if (startTag != null) {
          sb.write(startTag);
        }
        sb.write(text[col]);
        final endTag = endTags[position];
        if (endTag != null) {
          sb.write(endTag);
        }
      }
      sb.writeln();
    }
    return sb.toString();
  }
}
