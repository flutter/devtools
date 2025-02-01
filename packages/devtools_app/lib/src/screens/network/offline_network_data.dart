// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

import '../../shared/http/http_request_data.dart';
import '../network/network_controller.dart';
import 'network_model.dart';

/// Class to encapsulate offline data for the [NetworkController].
///
/// It is responsible for serializing and deserializing offline network data.
class OfflineNetworkData with Serializable {
  OfflineNetworkData({
    required this.httpRequestData,
    required this.socketData,
    this.selectedRequestId,
    required this.timelineMicrosOffset,
  });

  /// Creates an instance of [OfflineNetworkData] from a JSON map.
  factory OfflineNetworkData.fromJson(Map<String, Object?> json) {
    final httpRequestJsonList =
        json[_OfflineDataKeys.httpRequestData.name] as List<Object?>?;
    // Deserialize httpRequestData
    final httpRequestData =
        httpRequestJsonList
            ?.map((e) {
              if (e is Map<String, Object?>) {
                final requestData =
                    e[_OfflineDataKeys.request.name] as Map<String, Object?>?;
                return requestData != null
                    ? DartIOHttpRequestData.fromJson(requestData, null, null)
                    : null;
              }
              return null;
            })
            .whereType<DartIOHttpRequestData>()
            .toList() ??
        [];

    // Deserialize socketData
    final socketJsonList =
        json[_OfflineDataKeys.socketData.name] as List<Object?>?;
    final socketData =
        socketJsonList
            ?.map((e) {
              if (e is Map<String, Object?>) {
                return Socket.fromJson(e);
              }
              return null;
            })
            .whereType<Socket>()
            .toList() ??
        [];
    final timelineMicrosOffset = json['timelineMicrosOffset'];

    return OfflineNetworkData(
      httpRequestData: httpRequestData,
      selectedRequestId:
          json[_OfflineDataKeys.selectedRequestId.name] as String?,
      socketData: socketData,
      timelineMicrosOffset: timelineMicrosOffset as int? ?? 0,
    );
  }

  bool get isEmpty => httpRequestData.isEmpty && socketData.isEmpty;

  /// List of current [DartIOHttpRequestData] network requests.
  final List<DartIOHttpRequestData> httpRequestData;

  /// The ID of the currently selected request, if any.
  final String? selectedRequestId;

  /// used to calculate the correct wall-time for timeline events.
  final int? timelineMicrosOffset;

  /// The list of socket statistics for the offline network data.
  final List<Socket> socketData;

  /// Converts the current offline data to a JSON format.
  @override
  Map<String, Object?> toJson() {
    return {
      _OfflineDataKeys.httpRequestData.name:
          httpRequestData.map((e) => e.toJson()).toList(),
      _OfflineDataKeys.selectedRequestId.name: selectedRequestId,
      _OfflineDataKeys.socketData.name:
          socketData.map((e) => e.toJson()).toList(),
      _OfflineDataKeys.timelineMicrosOffset.name: timelineMicrosOffset,
    };
  }
}

enum _OfflineDataKeys {
  httpRequestData,
  selectedRequestId,
  socketData,
  request,
  timelineMicrosOffset,
}
