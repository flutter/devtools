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
  factory HarDataEntry.fromJson(Map<String, dynamic> json) {
    _convertHeaders(json);

    final modifiedRequestData = _remapCustomFieldKeys(json);

    // Retrieving url, method from requestData
    modifiedRequestData[NetworkEventKeys.uri.name] =
        (modifiedRequestData[NetworkEventKeys.request.name]
            as Map<String, dynamic>)[NetworkEventKeys.url.name];
    modifiedRequestData[NetworkEventKeys.method.name] =
        (modifiedRequestData[NetworkEventKeys.request.name]
            as Map<String, dynamic>)[NetworkEventKeys.method.name];

    // Adding missing keys which are mandatory for parsing
    (modifiedRequestData[NetworkEventKeys.response.name]
        as Map<String, dynamic>)[NetworkEventKeys.redirects.name] = [];
    dynamic requestPostData;
    dynamic responseContent;
    if (modifiedRequestData[NetworkEventKeys.response.name] != null &&
        (modifiedRequestData[NetworkEventKeys.response.name]
                as Map<String, dynamic>)[NetworkEventKeys.content.name] !=
            null) {
      responseContent = (modifiedRequestData[NetworkEventKeys.response.name]
          as Map<String, dynamic>)[NetworkEventKeys.content.name];
    }

    if (modifiedRequestData[NetworkEventKeys.request.name] != null &&
        (modifiedRequestData[NetworkEventKeys.request.name]
                as Map<String, dynamic>)[NetworkEventKeys.postData.name] !=
            null) {
      requestPostData = (modifiedRequestData[NetworkEventKeys.response.name]
          as Map<String, dynamic>)[NetworkEventKeys.content.name];
    }

    return HarDataEntry(
      DartIOHttpRequestData.fromJson(
        modifiedRequestData,
        requestPostData as Map<String, dynamic>,
        responseContent as Map<String, dynamic>,
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

  static Map<String, dynamic> _convertHeadersListToMap(
    List<dynamic> serializedHeaders,
  ) {
    final transformedHeaders = <String, dynamic>{};

    for (final header in serializedHeaders) {
      if (header is Map<String, dynamic>) {
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
  static void _convertHeaders(Map<String, dynamic> requestData) {
    // Request Headers
    if (requestData[NetworkEventKeys.request.name] != null &&
        (requestData[NetworkEventKeys.request.name]
                as Map<String, dynamic>)[NetworkEventKeys.headers.name] !=
            null) {
      if ((requestData[NetworkEventKeys.request.name]
          as Map<String, dynamic>)[NetworkEventKeys.headers.name] is List) {
        (requestData[NetworkEventKeys.request.name]
                as Map<String, dynamic>)[NetworkEventKeys.headers.name] =
            _convertHeadersListToMap(
          ((requestData[NetworkEventKeys.request.name]
                  as Map<String, dynamic>)[NetworkEventKeys.headers.name])
              as List<dynamic>,
        );
      }
    }

    // Response Headers
    if (requestData[NetworkEventKeys.response.name] != null &&
        (requestData[NetworkEventKeys.response.name]
                as Map<String, dynamic>)[NetworkEventKeys.headers.name] !=
            null) {
      if ((requestData[NetworkEventKeys.response.name]
          as Map<String, dynamic>)[NetworkEventKeys.headers.name] is List) {
        (requestData[NetworkEventKeys.response.name]
                as Map<String, dynamic>)[NetworkEventKeys.headers.name] =
            _convertHeadersListToMap(
          ((requestData[NetworkEventKeys.response.name]
                  as Map<String, dynamic>)[NetworkEventKeys.headers.name])
              as List<dynamic>,
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

    final convertedMap = <String, dynamic>{};

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
