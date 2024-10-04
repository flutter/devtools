// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/utils.dart';

/// Class to encapsulate offline data for the [NetworkController].
/// It is responsible for serializing and deserializing offline network data.
class OfflineNetworkData with Serializable {
  OfflineNetworkData({
    required this.requests,
    this.selectedRequestId,
    this.recording = false,
  });

  /// Creates an instance of [OfflineNetworkData] from a JSON map.
  factory OfflineNetworkData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> requestsJson = json['requests'] ?? [];
    final requests = requestsJson
        .map(
          (e) => DartIOHttpRequestData.fromJson(
            e as Map<String, dynamic>,
            null,
            null,
          ),
        )
        .toList();

    return OfflineNetworkData(
      requests: requests,
      selectedRequestId: json['selectedRequestId'] as String?,
      recording: json['recording'] as bool? ?? false,
    );
  }
  bool get isEmpty => requests.isNullOrEmpty;

  /// List of current [DartIOHttpRequestData] network requests.
  final List<DartIOHttpRequestData> requests;

  /// The ID of the currently selected request, if any.
  final String? selectedRequestId;

  /// Whether the recording state is enabled.
  final bool recording;

  /// Converts the current offline data to a JSON format.
  @override
  Map<String, dynamic> toJson() {
    return {
      'requests': requests.map((request) => request.toJson()).toList(),
      'selectedRequestId': selectedRequestId,
      'recording': recording,
    };
  }
}
