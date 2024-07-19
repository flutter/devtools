// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import '../../shared/http/http_request_data.dart';
import 'constants.dart';
import 'har_builder.dart';

/// A class that represents network data in the HTTP Archive (HAR) format.
///
/// This class implements the [Serializable] interface, allowing instances to
/// be serialized to and from JSON.
class HarNetworkData with Serializable {
  /// Creates an instance of [HarNetworkData] with a list of [DartIOHttpRequestData] requests.
  ///
  /// The [requests] parameter should contain the list of [DartIOHttpRequestData] request data.
  HarNetworkData(this.requests);

  /// Creates an instance of [HarNetworkData] from a JSON object.
  ///
  /// This factory constructor expects the [json] parameter to be a Map
  /// representing the HAR data, with a structure containing a 'log' key,
  /// which in turn contains an 'entries' key. Each entry in the 'entries'
  /// list should be a Map representing an HTTP request.
  ///
  /// ```dart
  /// final harData = HarNetworkData.fromJson(json);
  /// ```
  factory HarNetworkData.fromJson(Map<String, Object?> json) {
    final entries = ((json[NetworkEventKeys.log.name]
                as Map<String, Object?>)[NetworkEventKeys.entries.name]
            as List<Object?>)
        .map(
          (entryJson) =>
              HarDataEntry.fromJson(entryJson as Map<String, Object?>)
                  .toDartIOHttpRequest(),
        )
        .toList();

    return HarNetworkData(entries);
  }

  /// The list of [DartIOHttpRequestData] request data.
  final List<DartIOHttpRequestData> requests;

  /// Converts the instance to a JSON object.
  ///
  /// This method returns a Map representing the HAR data, suitable for
  /// serialization.
  ///
  /// ```dart
  /// final json = harData.toJson();
  /// ```
  @override
  Map<String, Object?> toJson() {
    return buildHar(requests);
  }
}

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
    final requestData = modifiedRequestData[NetworkEventKeys.request.name]
        as Map<String, Object?>;
    modifiedRequestData[NetworkEventKeys.uri.name] =
        requestData[NetworkEventKeys.url.name];
    modifiedRequestData[NetworkEventKeys.method.name] =
        requestData[NetworkEventKeys.method.name];

    // Adding missing keys which are mandatory for parsing
    final responseData = modifiedRequestData[NetworkEventKeys.response.name]
        as Map<String, Object?>;
    responseData[NetworkEventKeys.redirects.name] = <Map<String, Object?>>[];
    Object? requestPostData;
    Object? responseContent;
    if (responseData[NetworkEventKeys.content.name] != null) {
      responseContent = responseData[NetworkEventKeys.content.name];
    }

    if (requestData[NetworkEventKeys.postData.name] != null) {
      requestPostData = responseData[NetworkEventKeys.content.name];
    }

    return HarDataEntry(
      DartIOHttpRequestData.fromJson(
        modifiedRequestData,
        requestPostData as Map<String, Object?>,
        responseContent as Map<String, Object?>,
      ),
    );
  }

  final DartIOHttpRequestData request;

  /// Converts the instance to a JSON object.
  ///
  /// This method returns a Map representing a single HAR entry, suitable for
  /// serialization.
  Map<String, Object?> toJson() {
    // Implement the logic to convert DartIOHttpRequestData to HAR entry format
    return {};
  }

  /// Converts the HAR data entry back to [DartIOHttpRequestData].
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

  // Convert list of headers to map
  static void _convertHeaders(Map<String, Object?> requestData) {
    final reqData =
        requestData[NetworkEventKeys.request.name] as Map<String, Object?>;
    // Request Headers
    if (reqData[NetworkEventKeys.headers.name] != null) {
      if (reqData[NetworkEventKeys.headers.name] is List) {
        reqData[NetworkEventKeys.headers.name] = _convertHeadersListToMap(
          (reqData[NetworkEventKeys.headers.name]) as List<Object?>,
        );
      }
    }

    // Response Headers
    final resData =
        requestData[NetworkEventKeys.response.name] as Map<String, Object?>;
    if (resData[NetworkEventKeys.headers.name] != null) {
      if (resData[NetworkEventKeys.headers.name] is List) {
        resData[NetworkEventKeys.headers.name] = _convertHeadersListToMap(
          (resData[NetworkEventKeys.headers.name]) as List<Object?>,
        );
      }
    }
  }

  // Removing underscores from custom fields
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
