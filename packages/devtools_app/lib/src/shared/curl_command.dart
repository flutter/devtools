// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../http/http_request_data.dart';

/// [CurlCommand] provides the ability to create a cURL command string
/// based on the passed [DartIOHttpRequestData].
class CurlCommand {
  /// When [followRedirects] is false, the `--location` option is omitted from cURL.
  /// When [multiline] is false, the command will be forced to be in a single line.
  CurlCommand(this._data, {bool followRedirects = true, bool multiline = true})
      : _followRedirects = followRedirects,
        _multiline = multiline {
    if (_followRedirects) {
      _addPart('--location');
    }
    _addPart('--request');
    _addPart(_data.method);
    _addPart(_escapeString(_data.uri));
    _addHeaders();
    _addBody();
  }

  final bool _followRedirects;
  final bool _multiline;
  final List<String> _commandParts = ['curl'];
  final Set<int> _lineBreakIndexes = {};
  final DartIOHttpRequestData _data;

  /// Returns the cURL command as a string.
  @override
  String toString() {
    return _buildCommandString(_commandParts, _lineBreakIndexes);
  }

  void _addHeaders() {
    final headers = _data.requestHeaders;

    if (headers != null && headers.isNotEmpty) {
      for (final header in headers.entries) {
        final headerKey = header.key.toLowerCase();
        final headerValue = _unwrapHeaderValue(header.value);

        if (headerValue == null) continue;

        _addLineBreak();
        _addPart('--header');
        _addPart(_escapeString('$headerKey: $headerValue'));
      }
    }
  }

  void _addBody() {
    final requestBody = _data.requestBody;

    if (requestBody != null) {
      _addLineBreak();
      _addPart('--data-raw');
      _addPart(_escapeString(requestBody));
    }
  }

  /// Add a part into the command, which is separated by whitespace.
  void _addPart(String value) {
    _commandParts.add(value);
  }

  /// Add a line break at the current position.
  void _addLineBreak() {
    if (!_multiline) return;

    _lineBreakIndexes.add(_commandParts.length - 1);
  }

  /// Escapes an arbitrary string by wrapping it inside single quotes.
  ///
  /// Enclosing characters in single quotes preserves the literal value of each
  /// character in the string. Single quotes can't occur within, which is why it
  /// is necessary to replace all occurences of the character ' with '\''.
  ///
  /// See: https://www.gnu.org/software/bash/manual/html_node/Quoting.html
  String _escapeString(String text) {
    final content = text.replaceAll("'", "'\\''");

    return "'$content'";
  }

  String? _unwrapHeaderValue(dynamic value) {
    if (value is String) {
      return value;
    } else if (value is List<dynamic>) {
      if (value.isNotEmpty && value.first is String) {
        return value.first;
      }
    }

    return null;
  }

  /// Given a list of [commandParts] and [lineBreakIndexes], build the cURL
  /// command string.
  static String _buildCommandString(
    List<String> commandParts,
    Set<int> lineBreakIndexes,
  ) {
    String commandString = '';
    bool addSpace = false;

    for (int index = 0; index < commandParts.length; index++) {
      if (addSpace) {
        commandString += ' ';
      }
      commandString += commandParts[index];

      // Insert a line break if the index is contained in `lineBreakIndexes`.
      // Don't insert when this is the last line.
      if (lineBreakIndexes.contains(index) &&
          index != commandParts.length - 1) {
        commandString += ' \\\n';

        // Since a new line was added, don't prepend a space to the next line.
        addSpace = false;
        continue;
      }

      addSpace = true;
    }

    return commandString;
  }
}
