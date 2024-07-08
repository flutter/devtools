// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../../shared/http/http_request_data.dart';
import '../../shared/utils.dart';
import 'constants.dart';

/// Builds a HAR (HTTP Archive) object from a list of HTTP requests.
///
/// The HAR format is a JSON-based format used for logging a web browser's
/// interaction with a site. It is useful for performance analysis and
/// debugging. This function constructs the HAR object based on the 1.2
/// specification.
///
/// For more details on the HAR format, see the [HAR 1.2 Specification](https://github.com/ahmadnassri/har-spec/blob/master/versions/1.2.md).
///
/// Parameters:
/// - [httpRequests]: A list of DartIOHttpRequestData data.
///
/// Returns:
/// - A Map representing the HAR object.
Map<String, Object?> buildHar(List<DartIOHttpRequestData> httpRequests) {
  // Build the creator
  final creator = <String, Object?>{
    NetworkEventKeys.name.name: NetworkEventDefaults.creatorName,
    NetworkEventKeys.creatorVersion.name: devToolsVersion,
  };

  // Build the entries
  final entries = httpRequests.map((e) {
    final requestCookies = e.requestCookies.map((cookie) {
      return <String, Object?>{
        NetworkEventKeys.name.name: cookie.name,
        NetworkEventKeys.value.name: cookie.value,
        'path': cookie.path,
        'domain': cookie.domain,
        'expires': cookie.expires?.toUtc().toIso8601String(),
        'httpOnly': cookie.httpOnly,
        'secure': cookie.secure,
      };
    }).toList();

    final requestHeaders = e.requestHeaders?.entries.map((header) {
      var value = header.value;
      if (value is List) {
        value = value.first;
      }
      return <String, Object?>{
        NetworkEventKeys.name.name: header.key,
        NetworkEventKeys.value.name: value,
      };
    }).toList();

    final queryString = Uri.parse(e.uri).queryParameters.entries.map((param) {
      return <String, Object?>{
        NetworkEventKeys.name.name: param.key,
        NetworkEventKeys.value.name: param.value,
      };
    }).toList();

    final responseCookies = e.responseCookies.map((cookie) {
      return <String, Object?>{
        NetworkEventKeys.name.name: cookie.name,
        NetworkEventKeys.value.name: cookie.value,
        'path': cookie.path,
        'domain': cookie.domain,
        'expires': cookie.expires?.toUtc().toIso8601String(),
        'httpOnly': cookie.httpOnly,
        'secure': cookie.secure,
      };
    }).toList();

    final responseHeaders = e.responseHeaders?.entries.map((header) {
      var value = header.value;
      if (value is List) {
        value = value.first;
      }
      return <String, Object?>{
        NetworkEventKeys.name.name: header.key,
        NetworkEventKeys.value.name: value,
      };
    }).toList();

    return <String, Object?>{
      NetworkEventKeys.startedDateTime.name:
          e.startTimestamp.toUtc().toIso8601String(),
      NetworkEventKeys.time.name: e.duration?.inMilliseconds,
      // Request
      NetworkEventKeys.request.name: <String, Object?>{
        NetworkEventKeys.method.name: e.method.toUpperCase(),
        NetworkEventKeys.url.name: e.uri.toString(),
        NetworkEventKeys.httpVersion.name: NetworkEventDefaults.httpVersion,
        NetworkEventKeys.cookies.name: requestCookies,
        NetworkEventKeys.headers.name: requestHeaders,
        NetworkEventKeys.queryString.name: queryString,
        NetworkEventKeys.postData.name: <String, Object?>{
          NetworkEventKeys.mimeType.name: e.contentType,
          NetworkEventKeys.text.name: e.requestBody,
        },
        NetworkEventKeys.headersSize.name:
            _calculateHeadersSize(e.requestHeaders),
        NetworkEventKeys.bodySize.name: _calculateBodySize(e.requestBody),
      },
      // Response
      NetworkEventKeys.response.name: <String, Object?>{
        NetworkEventKeys.status.name: e.status,
        NetworkEventKeys.statusText.name: '',
        NetworkEventKeys.httpVersion.name:
            NetworkEventDefaults.responseHttpVersion,
        NetworkEventKeys.cookies.name: responseCookies,
        NetworkEventKeys.headers.name: responseHeaders,
        NetworkEventKeys.content.name: <String, Object?>{
          NetworkEventKeys.size.name: e.responseBody?.length,
          NetworkEventKeys.mimeType.name: e.type,
          NetworkEventKeys.text.name: e.responseBody,
        },
        NetworkEventKeys.redirectURL.name: '',
        NetworkEventKeys.headersSize.name:
            _calculateHeadersSize(e.responseHeaders),
        NetworkEventKeys.bodySize.name: _calculateBodySize(e.responseBody),
      },
      // Cache
      NetworkEventKeys.cache.name: <String, Object?>{},
      NetworkEventKeys.timings.name: <String, Object?>{
        NetworkEventKeys.blocked.name: NetworkEventDefaults.blocked,
        NetworkEventKeys.dns.name: NetworkEventDefaults.dns,
        NetworkEventKeys.connect.name: NetworkEventDefaults.connect,
        NetworkEventKeys.send.name: NetworkEventDefaults.send,
        NetworkEventKeys.wait.name: e.duration!.inMilliseconds - 2,
        NetworkEventKeys.receive.name: NetworkEventDefaults.receive,
        NetworkEventKeys.ssl.name: NetworkEventDefaults.ssl,
      },
      NetworkEventKeys.connection.name: e.hashCode.toString(),
      NetworkEventKeys.comment.name: '',
    };
  }).toList();

  // Assemble the final HAR object
  return <String, Object?>{
    NetworkEventKeys.log.name: <String, Object?>{
      NetworkEventKeys.version.name: NetworkEventDefaults.logVersion,
      NetworkEventKeys.creator.name: creator,
      NetworkEventKeys.entries.name: entries,
    },
  };
}

int _calculateHeadersSize(Map<String, dynamic>? headers) {
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

int _calculateBodySize(String? requestBody) {
  if (requestBody == null || requestBody.isEmpty) {
    return 0;
  }
  return utf8.encode(requestBody).length;
}
