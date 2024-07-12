import 'package:flutter/foundation.dart';

import '../../../devtools_app.dart';
import 'har_builder.dart';
// ignore_for_file: avoid_dynamic_calls

class HarNetworkData {
  HarNetworkData(this.requests);

  factory HarNetworkData.fromJson(Map<String, dynamic> json) {
    final entries = (json['log']?['entries'] as List<dynamic>? ?? [])
        .map(
          (entryJson) =>
              DartIOHttpRequestData.fromJson(entryJson as Map<String, dynamic>),
        )
        .toList();

    return HarNetworkData(entries);
  }

  final List<DartIOHttpRequestData> requests;

  Map<String, Object?> toJson() {
    return buildHar(requests);
  }
}
