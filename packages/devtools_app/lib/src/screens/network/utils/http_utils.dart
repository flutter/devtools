// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// Calculates the size of the headers in bytes.
///
/// Takes a map of headers [headers], where keys are header names and values
/// can be strings or lists of strings. Returns the size of the headers
/// in bytes or -1 if [headers] is null.
int calculateHeadersSize(Map<String, Object?>? headers) {
  if (headers == null) return -1;

  // Combine headers into a single string with CRLF endings
  String headersString =
      headers.entries.map((entry) {
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
