// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_shared/devtools_shared.dart';

import '../../shared/http/http_request_data.dart';
import '../../shared/primitives/utils.dart';
import '../network/network_controller.dart';
import 'network_model.dart';

/// Class to encapsulate offline data for the [NetworkController].
///
/// It is responsible for serializing and deserializing offline network data.
class OfflineNetworkData with Serializable {
  OfflineNetworkData({
    required this.httpRequestData,
    this.selectedRequestId,
    required this.socketData,
  });

  /// Creates an instance of [OfflineNetworkData] from a JSON map.
  factory OfflineNetworkData.fromJson(Map<String, Object?> json) {
    final httpRequestJsonList =
        json[OfflineDataKeys.httpRequestData.name] as List<Object>?;

    // Deserialize httpRequestData
    final httpRequestData = httpRequestJsonList
            ?.map((e) {
              if (e is Map<String, Object?>) {
                final requestData =
                    e[OfflineDataKeys.request.name] as Map<String, Object?>?;
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
        json[OfflineDataKeys.socketData.name] as List<Object>?;
    final socketData = socketJsonList
            ?.map((e) {
              if (e is Map<String, Object?>) {
                return Socket.fromJson(e);
              }
              return null;
            })
            .whereType<Socket>()
            .toList() ??
        [];

    return OfflineNetworkData(
      httpRequestData: httpRequestData,
      selectedRequestId:
          json[OfflineDataKeys.selectedRequestId.name] as String?,
      socketData: socketData,
    );
  }

  bool get isEmpty => httpRequestData.isNullOrEmpty && socketData.isNullOrEmpty;

  /// List of current [DartIOHttpRequestData] network requests.
  final List<DartIOHttpRequestData> httpRequestData;

  /// The ID of the currently selected request, if any.
  final String? selectedRequestId;

  /// Socket statistics
  final List<Socket> socketData;

  /// Converts the current offline data to a JSON format.
  @override
  Map<String, Object?> toJson() {
    return {
      OfflineDataKeys.httpRequestData.name:
          httpRequestData.map((e) => e.toJson()).toList(),
      OfflineDataKeys.selectedRequestId.name: selectedRequestId,
      OfflineDataKeys.socketData.name: socketData,
      OfflineDataKeys.socketData.name:
          socketData.map((e) => e.toJson()).toList(),
    };
  }
}

enum OfflineDataKeys {
  httpRequestData,
  selectedRequestId,
  socketData,
  request,
}
