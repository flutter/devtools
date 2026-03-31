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

// Output Formats:
// - 512 → "512 B"
// - 2000 → "2.0 kB"
// - 1000000 → "1.0 MB"
// Values are rounded to one decimal place for kB and MB.
// Uses decimal (base-10) units to match Chrome DevTools.
String formatBytes(int? bytes) {
  if (bytes == null) return '-';
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) {
    return '${(bytes / 1000).toStringAsFixed(1)} kB';
  }
  return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
}
