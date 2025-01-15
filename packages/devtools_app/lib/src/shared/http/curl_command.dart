// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import '../primitives/utils.dart';
import 'http_request_data.dart';

class CurlCommand {
  /// [CurlCommand] provides the ability to create a cURL command string
  /// based on the passed [DartIOHttpRequestData].
  ///
  /// When [followRedirects] is false, the `--location` option is omitted from cURL.
  /// When [multiline] is false, the command will be forced to be in a single line.
  factory CurlCommand.from(
    DartIOHttpRequestData data, {
    bool followRedirects = true,
    bool multiline = true,
  }) {
    return CurlCommand._(
      commandParts: [
        'curl',
        if (followRedirects) '--location',
        '--request',
        data.method,
        _escapeString(data.uri),
        ..._headers(data, multiline: multiline),
        ..._body(data, multiline: multiline),
      ],
    );
  }

  CurlCommand._({required this.commandParts});

  static const _lineBreak = '\\\n';

  final List<String> commandParts;

  /// Returns the cURL command as a string.
  @override
  String toString() {
    return _buildCommandString(commandParts);
  }

  static List<String> _headers(
    DartIOHttpRequestData data, {
    required bool multiline,
  }) {
    final parts = <String>[];
    final headers = data.requestHeaders;

    if (headers != null && headers.isNotEmpty) {
      for (final header in headers.entries) {
        final headerKey = header.key.toLowerCase();
        final headerValue = _unwrapHeaderValue(header.value);

        if (headerValue == null) continue;

        parts.addAll([
          if (multiline) _lineBreak,
          '--header',
          _escapeString('$headerKey: $headerValue'),
        ]);
      }
    }

    return parts;
  }

  static List<String> _body(
    DartIOHttpRequestData data, {
    required bool multiline,
  }) {
    final requestBody = data.requestBody;
    if (requestBody == null) return [];

    return [
      if (multiline) _lineBreak,
      '--data-raw',
      _escapeString(requestBody),
    ];
  }

  /// Escapes an arbitrary string by wrapping it inside single quotes.
  ///
  /// Enclosing characters in single quotes preserves the literal value of each
  /// character in the string. Single quotes can't occur within, which is why it
  /// is necessary to replace all occurrences of the character ' with '\''.
  ///
  /// See: https://www.gnu.org/software/bash/manual/html_node/Quoting.html
  static String _escapeString(String text) {
    final content = text.replaceAll("'", "'\\''");

    return "'$content'";
  }

  static String? _unwrapHeaderValue(Object? value) {
    if (value is String) {
      return value;
    } else if (value is List<Object?>) {
      return value.safeFirst as String?;
    }

    return null;
  }

  /// Given a list of [commandParts], build the cURL command string.
  static String _buildCommandString(List<String> commandParts) {
    String commandString = '';

    for (int index = 0; index < commandParts.length; index++) {
      final previousPart = commandParts.safeGet(index - 1);

      // Only insert a space when this is not the first element AND the previous
      // part is not a line break.
      if (index != 0 && previousPart != _lineBreak) {
        commandString += ' ';
      }

      commandString += commandParts[index];
    }

    return commandString;
  }
}
