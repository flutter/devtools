// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../../screens/network/utils/http_utils.dart';
import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/utils.dart';
import 'constants.dart';

/// A class representing a single entry in the HTTP Archive (HAR) format.
///
/// This class is used to parse and handle data from HAR entries, converting
/// them into [DartIOHttpRequestData] objects which represent HTTP request data.
///
/// This class also provides functionality to convert its instances back to
/// JSON format, maintaining the HAR entry structure.
class HarDataEntry {
  HarDataEntry(this.request);

  /// Creates an instance of [HarDataEntry] from a JSON object.
  ///
  /// This factory constructor expects the [json] parameter to be a Map
  /// representing a single HAR entry.
  factory HarDataEntry.fromJson(Map<String, Object?> json) {
    _convertHeaders(json);

    final modifiedRequestData = _remapCustomFieldKeys(json);

    // Retrieving url, method from requestData
    final requestData =
        modifiedRequestData[NetworkEventKeys.request.name]
            as Map<String, Object?>;
    modifiedRequestData[NetworkEventKeys.uri.name] =
        requestData[NetworkEventKeys.url.name];
    modifiedRequestData[NetworkEventKeys.method.name] =
        requestData[NetworkEventKeys.method.name];

    // Adding missing keys which are mandatory for parsing
    final responseData =
        modifiedRequestData[NetworkEventKeys.response.name]
            as Map<String, Object?>;
    responseData[NetworkEventKeys.redirects.name] = <Map<String, Object?>>[];
    final requestPostData = responseData[NetworkEventKeys.postData.name];
    final responseContent = responseData[NetworkEventKeys.content.name];

    return HarDataEntry(
      DartIOHttpRequestData.fromJson(
        modifiedRequestData,
        requestPostData as Map<String, Object?>?,
        responseContent as Map<String, Object?>?,
      ),
    );
  }

  final DartIOHttpRequestData request;

  /// Converts the instance to a JSON object.
  ///
  /// This method returns a Map representing a single HAR entry, suitable for
  /// serialization.
  static Map<String, Object?> toJson(DartIOHttpRequestData e) {
    // Implement the logic to convert DartIOHttpRequestData to HAR entry format
    final requestCookies =
        e.requestCookies.map((cookie) {
          return <String, Object?>{
            NetworkEventKeys.name.name: cookie.name,
            NetworkEventKeys.value.name: cookie.value,
            NetworkEventKeys.path.name: cookie.path,
            NetworkEventKeys.domain.name: cookie.domain,
            NetworkEventKeys.expires.name:
                cookie.expires?.toUtc().toIso8601String(),
            NetworkEventKeys.httpOnly.name: cookie.httpOnly,
            NetworkEventKeys.secure.name: cookie.secure,
          };
        }).toList();

    final requestHeaders =
        e.requestHeaders?.entries.map((header) {
          var value = header.value;
          if (value is List) {
            value = value.first;
          }
          return <String, Object?>{
            NetworkEventKeys.name.name: header.key,
            NetworkEventKeys.value.name: value,
          };
        }).toList();

    final queryString =
        Uri.parse(e.uri).queryParameters.entries.map((param) {
          return <String, Object?>{
            NetworkEventKeys.name.name: param.key,
            NetworkEventKeys.value.name: param.value,
          };
        }).toList();

    final responseCookies =
        e.responseCookies.map((cookie) {
          return <String, Object?>{
            NetworkEventKeys.name.name: cookie.name,
            NetworkEventKeys.value.name: cookie.value,
            NetworkEventKeys.path.name: cookie.path,
            NetworkEventKeys.domain.name: cookie.domain,
            NetworkEventKeys.expires.name:
                cookie.expires?.toUtc().toIso8601String(),
            NetworkEventKeys.httpOnly.name: cookie.httpOnly,
            NetworkEventKeys.secure.name: cookie.secure,
          };
        }).toList();

    final responseHeaders =
        e.responseHeaders?.entries.map((header) {
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
        NetworkEventKeys.headersSize.name: calculateHeadersSize(
          e.requestHeaders,
        ),
        NetworkEventKeys.bodySize.name: _calculateBodySize(e.requestBody),
      },
      // Response
      NetworkEventKeys.response.name: <String, Object?>{
        NetworkEventKeys.status.name: e.status,
        NetworkEventKeys.statusText.name:
            e.general[NetworkEventKeys.reasonPhrase.name] ?? '',
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
        NetworkEventKeys.headersSize.name: calculateHeadersSize(
          e.responseHeaders,
        ),
        NetworkEventKeys.bodySize.name: _calculateBodySize(e.responseBody),
      },
      // Cache
      NetworkEventKeys.cache.name: <String, Object?>{},
      NetworkEventKeys.timings.name: <String, Object?>{
        NetworkEventKeys.blocked.name: NetworkEventDefaults.blocked,
        NetworkEventKeys.dns.name: NetworkEventDefaults.dns,
        NetworkEventKeys.connect.name: NetworkEventDefaults.connect,
        NetworkEventKeys.send.name: NetworkEventDefaults.send,
        NetworkEventKeys.wait.name: e.duration?.inMilliseconds ?? 0,
        NetworkEventKeys.receive.name: NetworkEventDefaults.receive,
        NetworkEventKeys.ssl.name: NetworkEventDefaults.ssl,
      },
      NetworkEventKeys.connection.name: e.hashCode.toString(),
      NetworkEventKeys.comment.name: '',

      // Custom fields
      // har spec requires underscore to be added for custom fields, hence removing them
      // Note: the 'isolateId' field is kept empty because DartIOHttpRequestData does not expose it
      // (but it is required by HttpProfileRequestRef.parse)
      NetworkEventCustomFieldKeys.isolateId: '',
      NetworkEventCustomFieldKeys.id: e.id,
      NetworkEventCustomFieldKeys.startTime:
          e.startTimestamp.microsecondsSinceEpoch,
      // Note: The 'events' field is kept empty because DartIOHttpRequestData does not expose it
      // (but it is required by HttpProfileRequestRef.parse)
      NetworkEventCustomFieldKeys.events: [],
    };
  }

  /// Returns the original [DartIOHttpRequestData] that this HAR entry was created from or parsed into.
  DartIOHttpRequestData toDartIOHttpRequest() {
    return request;
  }

  static Map<String, Object?> _convertHeadersListToMap(
    List<Object?> serializedHeaders,
  ) {
    final transformedHeaders = <String, Object?>{};

    for (final header in serializedHeaders) {
      if (header is Map<String, Object?>) {
        final key = header[NetworkEventKeys.name.name] as String?;
        final value = header[NetworkEventKeys.value.name];

        if (key != null) {
          if (transformedHeaders.containsKey(key)) {
            if (transformedHeaders[key] is List) {
              (transformedHeaders[key] as List).add(value);
            } else {
              transformedHeaders[key] = [transformedHeaders[key], value];
            }
          } else {
            transformedHeaders[key] = value;
          }
        }
      }
    }

    return transformedHeaders;
  }

  /// Convert list of headers to map
  static void _convertHeaders(Map<String, Object?> requestData) {
    final reqData =
        requestData[NetworkEventKeys.request.name] as Map<String, Object?>;
    // Request Headers
    if (reqData[NetworkEventKeys.headers.name] is List) {
      reqData[NetworkEventKeys.headers.name] = _convertHeadersListToMap(
        (reqData[NetworkEventKeys.headers.name]) as List<Object?>,
      );
    }

    // Response Headers
    final resData =
        requestData[NetworkEventKeys.response.name] as Map<String, Object?>;
    if (resData[NetworkEventKeys.headers.name] is List) {
      resData[NetworkEventKeys.headers.name] = _convertHeadersListToMap(
        (resData[NetworkEventKeys.headers.name]) as List<Object?>,
      );
    }
  }

  /// Removing underscores from custom fields
  static Map<String, Object?> _remapCustomFieldKeys(
    Map<String, Object?> originalMap,
  ) {
    final replacementMap = {
      NetworkEventCustomFieldKeys.isolateId:
          NetworkEventCustomFieldRemappedKeys.isolateId.name,
      NetworkEventCustomFieldKeys.id:
          NetworkEventCustomFieldRemappedKeys.id.name,
      NetworkEventCustomFieldKeys.startTime:
          NetworkEventCustomFieldRemappedKeys.startTime.name,
      NetworkEventCustomFieldKeys.events:
          NetworkEventCustomFieldRemappedKeys.events.name,
    };

    final convertedMap = <String, Object?>{};

    originalMap.forEach((key, value) {
      if (replacementMap.containsKey(key)) {
        convertedMap[replacementMap[key]!] = value;
      } else {
        convertedMap[key] = value;
      }
    });

    return convertedMap;
  }
}

int _calculateBodySize(String? requestBody) {
  if (requestBody.isNullOrEmpty) {
    return 0;
  }
  return utf8.encode(requestBody!).length;
}
