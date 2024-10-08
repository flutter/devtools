// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/utils.dart';
import '../network/network_controller.dart';
import 'network_model.dart';

/// Class to encapsulate offline data for the [NetworkController].
///
/// It is responsible for serializing and deserializing offline network data.
class OfflineNetworkData with Serializable {
  OfflineNetworkData({
    required this.requests,
    this.selectedRequestId,
    required this.currentRequests,
    required this.socketStats,
  });

  /// Creates an instance of [OfflineNetworkData] from a JSON map.
  factory OfflineNetworkData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> requestsJson = json['requests'] ?? [];
    final List<HttpProfileRequest>? currentReqData = json['currentRequests'];
    final List<SocketStatistic>? socketStats = json['socketStats'];

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
      currentRequests: currentReqData,
      socketStats: socketStats!,
    );
  }
  bool get isEmpty => requests.isNullOrEmpty;

  /// List of current [DartIOHttpRequestData] network requests.
  final List<DartIOHttpRequestData> requests;

  /// Get a request by matching its `id` field.
  // Temporarily added to check selection in the filtered requests data,
  // until we have current requests data in place
  NetworkRequest? getRequest(String id) {
    // Search through the list of requests and return the one with the matching ID.
    return requests.firstWhere(
      (request) => request.id == id,
    );
  }

  /// The ID of the currently selected request, if any.
  final String? selectedRequestId;

  /// Current requests from network controller.

  final List<HttpProfileRequest>? currentRequests;

  /// Socket statistics
  final List<SocketStatistic> socketStats;

  /// Converts the current offline data to a JSON format.
  @override
  Map<String, dynamic> toJson() {
    return {
      'requests': requests.map((request) => request.toJson()).toList(),
      'selectedRequestId': selectedRequestId,
      'currentRequests': currentRequests,
      'socketStats': socketStats,
    };
  }
}
