// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import '../../shared/http/http_request_data.dart';
import 'constants.dart';
import 'har_builder.dart';
import 'har_data_entry.dart';

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
    final entries =
        ((json[NetworkEventKeys.log.name]
                    as Map<String, Object?>)[NetworkEventKeys.entries.name]
                as List<Object?>)
            .map(
              (entryJson) =>
                  HarDataEntry.fromJson(
                    entryJson as Map<String, Object?>,
                  ).toDartIOHttpRequest(),
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
