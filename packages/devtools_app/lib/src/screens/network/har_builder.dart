// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../../shared/analytics/constants.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/utils.dart';

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
    NetworkEventKeys.name: NetworkEventDefaults.creatorName,
    NetworkEventKeys.creatorVersion: devToolsVersion,
  };

  // Build the entries
  final entries = httpRequests.map((e) {
    final requestCookies = e.requestCookies.map((cookie) {
      return <String, Object?>{
        NetworkEventKeys.name: cookie.name,
        NetworkEventKeys.value: cookie.value,
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
        NetworkEventKeys.name: header.key,
        NetworkEventKeys.value: value,
      };
    }).toList();

    final queryString = Uri.parse(e.uri).queryParameters.entries.map((param) {
      return <String, Object?>{
        NetworkEventKeys.name: param.key,
        NetworkEventKeys.value: param.value,
      };
    }).toList();

    final responseCookies = e.responseCookies.map((cookie) {
      return <String, Object?>{
        NetworkEventKeys.name: cookie.name,
        NetworkEventKeys.value: cookie.value,
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
        NetworkEventKeys.name: header.key,
        NetworkEventKeys.value: value,
      };
    }).toList();

    return <String, Object?>{
      NetworkEventKeys.startedDateTime:
          e.startTimestamp.toUtc().toIso8601String(),
      NetworkEventKeys.time: e.duration?.inMilliseconds,
      // Request
      NetworkEventKeys.request: <String, Object?>{
        NetworkEventKeys.method: e.method.toUpperCase(),
        NetworkEventKeys.url: e.uri.toString(),
        NetworkEventKeys.httpVersion: NetworkEventDefaults.httpVersion,
        NetworkEventKeys.cookies: requestCookies,
        NetworkEventKeys.headers: requestHeaders,
        NetworkEventKeys.queryString: queryString,
        NetworkEventKeys.postData: <String, Object?>{
          NetworkEventKeys.mimeType: e.contentType,
          NetworkEventKeys.text: e.requestBody,
        },
        NetworkEventKeys.headersSize: _calculateHeadersSize(e.requestHeaders),
        NetworkEventKeys.bodySize: _calculateBodySize(e.requestBody),
      },
      // Response
      NetworkEventKeys.response: <String, Object?>{
        NetworkEventKeys.status: e.status,
        NetworkEventKeys.statusText: '',
        NetworkEventKeys.httpVersion: NetworkEventDefaults.responseHttpVersion,
        NetworkEventKeys.cookies: responseCookies,
        NetworkEventKeys.headers: responseHeaders,
        NetworkEventKeys.content: <String, Object?>{
          NetworkEventKeys.size: e.responseBody?.length,
          NetworkEventKeys.mimeType: e.type,
          NetworkEventKeys.text: e.responseBody,
        },
        NetworkEventKeys.redirectURL: '',
        NetworkEventKeys.headersSize: _calculateHeadersSize(e.responseHeaders),
        NetworkEventKeys.bodySize: _calculateBodySize(e.responseBody),
      },
      // Cache
      NetworkEventKeys.cache: <String, Object?>{},
      NetworkEventKeys.timings: <String, Object?>{
        NetworkEventKeys.blocked: NetworkEventDefaults.blocked,
        NetworkEventKeys.dns: NetworkEventDefaults.dns,
        NetworkEventKeys.connect: NetworkEventDefaults.connect,
        NetworkEventKeys.send: NetworkEventDefaults.send,
        NetworkEventKeys.wait: e.duration!.inMilliseconds - 2,
        NetworkEventKeys.receive: NetworkEventDefaults.receive,
        NetworkEventKeys.ssl: NetworkEventDefaults.ssl,
      },
      NetworkEventKeys.connection: e.hashCode.toString(),
      NetworkEventKeys.comment: '',
    };
  }).toList();

  // Assemble the final HAR object
  return <String, Object?>{
    NetworkEventKeys.log: <String, Object?>{
      NetworkEventKeys.version: NetworkEventDefaults.logVersion,
      NetworkEventKeys.creator: creator,
      NetworkEventKeys.entries: entries,
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
