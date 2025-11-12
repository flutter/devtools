// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

/// Calculates the size of the headers in bytes.
///
/// Takes a map of headers [headers], where keys are header names and values
/// can be strings or lists of strings. Returns the size of the headers
/// in bytes or -1 if [headers] is null.
int calculateHeadersSize(Map<String, Object?>? headers) {
  if (headers == null) return -1;

  // Combine headers into a single string with CRLF endings
  String headersString = headers.entries.map((entry) {
    final key = entry.key;
    var value = entry.value;
    // If the value is a List, join it with a comma
    if (value is List<String>) {
      value = value.join(', ');
    }
    return '$key: $value\r\n';
  }).join();

  // Add final CRLF to indicate end of headers
  headersString += '\r\n';

  // Calculate the byte length of the headers string
  return utf8.encode(headersString).length;
}

/// Returns `true` if the given [mimeType] is considered textual and can be
/// safely decoded as UTF-8 without base64 encoding.
///
/// This function is useful for determining whether the content of an HTTP
/// request or response can be directly included in a HAR or JSON file as
/// human-readable text.
bool isTextMimeType(String? mimeType) {
  if (mimeType == null) return false;

  // Strip charset if present
  final cleanedMime = mimeType.split(';').first.trim().toLowerCase();

  return cleanedMime.startsWith('text/') ||
      cleanedMime == 'application/json' ||
      cleanedMime == 'application/javascript' ||
      cleanedMime == 'application/xml' ||
      cleanedMime.endsWith('+json') ||
      cleanedMime.endsWith('+xml');
}

/// Extracts and normalizes the `content-type` MIME type from the headers.
///
/// - Supports headers as either a `List<String>` or a single `String`.
/// - Strips any parameters (e.g., `charset=utf-8`) and converts to lowercase.
/// - Returns `null` if no valid MIME type is found.
///
/// Example:
///   - "application/json; charset=utf-8" → "application/json"
///   - ["text/html; charset=UTF-8"] → "text/html"
String? getHeadersMimeType(dynamic header) {
  if (header == null) return null;

  final dynamicValue = header is List
      ? (header.isNotEmpty ? header.first : null)
      : header;

  if (dynamicValue == null) return null;

  final value = dynamicValue.toString().trim();
  if (value.isEmpty) return null;

  final mime = value.split(';').first.trim().toLowerCase();
  return mime.isEmpty ? null : mime;
}

/// Converts the given [bodyBytes] to a String based on its [mimeType].
///
/// - If the MIME type is text-based (e.g., `application/json`, `text/html`),
///   it decodes the raw bytes as UTF-8 for readability.
/// - Otherwise, it Base64 encodes the bytes so they can be safely stored
///   in JSON-based exports such as HAR files.
String convertBodyBytesToString(List<int> bodyBytes, String? mimeType) {
  if (isTextMimeType(mimeType)) {
    return utf8.decode(bodyBytes);
  }
  return base64.encode(bodyBytes);
}
