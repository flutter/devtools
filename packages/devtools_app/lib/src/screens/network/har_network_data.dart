import 'package:devtools_shared/devtools_shared.dart';
import '../../shared/http/http_request_data.dart';

import 'har_builder.dart';

class HarNetworkData with Serializable {
  HarNetworkData(this.requests);

  factory HarNetworkData.fromJson(Map<String, Object?> json) {
    final entries = ((json['log'] as Map<String, Object?>)['entries']
            as List<Object?>)
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
