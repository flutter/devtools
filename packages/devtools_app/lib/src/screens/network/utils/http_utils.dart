// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'dart:convert';

import '../../../shared/http/http.dart';

const _setCookieHeader = 'set-cookie';
const _cookieHeader = 'cookie';

/// Returns [headers] as `key: value` lines, as they would appear on the wire.
///
/// Header values decoded from JSON are a `List<dynamic>` rather than a
/// `List<String>`, so any [Iterable] is treated as a multi-value header:
/// - `set-cookie` gets one line per value, since cookie dates
///   (`Expires=...`) contain commas.
/// - `cookie` values are joined with `; `.
/// - all other values are joined with `, `.
Iterable<String> _headerLines(Map<String, Object?> headers) sync* {
  for (final MapEntry(:key, :value) in headers.entries) {
    if (value is! Iterable) {
      yield '$key: $value';
      continue;
    }
    switch (key.toLowerCase()) {
      case _setCookieHeader:
        for (final cookie in value) {
          yield '$key: $cookie';
        }
      case _cookieHeader:
        yield '$key: ${value.join('; ')}';
      default:
        yield '$key: ${value.join(', ')}';
    }
  }
}

/// Calculates the size of the headers in bytes.
///
/// Takes a map of headers [headers], where keys are header names and values
/// can be strings or lists of strings. Returns the size of the headers
/// in bytes or -1 if [headers] is null.
int calculateHeadersSize(Map<String, Object?>? headers) {
  if (headers == null) return -1;

  // Combine headers into a single string with CRLF endings
  String headersString = _headerLines(
    headers,
  ).map((line) => '$line\r\n').join();

  // Add final CRLF to indicate end of headers
  headersString += '\r\n';

  // Calculate the byte length of the headers string
  return utf8.encode(headersString).length;
}

/// Formats [headers] as `key: value` lines, as they would appear on the wire,
/// suitable for copying.
///
/// Returns an empty string if [headers] is null.
String headersToText(Map<String, Object?>? headers) =>
    headers == null ? '' : _headerLines(headers).join('\n');

/// Formats [info] as plain `key: value` lines, the way the General section of
/// the Headers tab displays them.
///
/// Unlike [headersToText], values are not treated as multi-value headers, since
/// the General section holds request details like `redirects` rather than HTTP
/// headers.
String generalInfoToText(Map<String, Object?> info) =>
    info.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');

String _cookieNameAndValue(Cookie cookie) => '${cookie.name}=${cookie.value}';

/// Formats request [cookies] the way they are sent in a `Cookie` header:
/// `name=value; name2=value2`.
String requestCookiesToText(List<Cookie> cookies) =>
    cookies.map(_cookieNameAndValue).join('; ');

/// Formats response cookies as one `Set-Cookie` value per line.
///
/// Prefers the raw `set-cookie` values in [responseHeaders], since parsing a
/// [Cookie] drops attributes like `Max-Age` and `SameSite`. Falls back to
/// `name=value` from [cookies] when the header is not available.
String responseCookiesToText(
  List<Cookie> cookies,
  Map<String, Object?>? responseHeaders,
) {
  final rawCookies = responseHeaders?.entries
      .where((entry) => entry.key.toLowerCase() == _setCookieHeader)
      .expand(
        (entry) =>
            entry.value is Iterable ? entry.value as Iterable : [entry.value],
      )
      .nonNulls
      .toList();
  if (rawCookies != null && rawCookies.isNotEmpty) {
    return rawCookies.join('\n');
  }
  return cookies.map(_cookieNameAndValue).join('\n');
}

// Output Formats:
// - 512 → "512 B"
// - 2000 → "2.0 kB"
// - 1000000 → "1.0 MB"
// Values are rounded to one decimal place for kB and MB.
// Uses decimal (base-10) units to match Chrome DevTools.
String formatBytes(int? bytes) {
  if (bytes == null || bytes < 0) return '-';
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) {
    return '${(bytes / 1000).toStringAsFixed(1)} kB';
  }
  return '${(bytes / (1000 * 1000)).toStringAsFixed(1)} MB';
}
