import 'package:devtools_shared/devtools_shared.dart';
import '../../shared/http/http_request_data.dart';

import 'har_builder.dart';
// ignore_for_file: avoid_dynamic_calls

class HarNetworkData with Serializable {
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

  @override
  Map<String, Object?> toJson() {
    return buildHar(requests);
  }
}
