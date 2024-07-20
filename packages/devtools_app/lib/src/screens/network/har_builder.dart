// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../../shared/http/http_request_data.dart';
import '../../shared/utils.dart';
import 'constants.dart';
import 'har_data_entry.dart';

/// Builds a HAR (HTTP Archive) object from a list of HTTP requests.
///
/// The HAR format is a JSON-based format used for logging a web browser's
/// interaction with a site. It is useful for performance analysis and
/// debugging. This function constructs the HAR object based on the 1.2
/// specification.
///
/// For more details on the HAR format, see the [HAR 1.2 Specification](https://github.com/ahmadnassri/har-spec/blob/master/versions/1.2.md).
///
/// Parameters:
/// - [httpRequests]: A list of [DartIOHttpRequestData] data.
///
/// Returns:
/// - A Map representing the HAR object.
Map<String, Object?> buildHar(List<DartIOHttpRequestData> httpRequests) {
  // Build the creator
  final creator = <String, Object?>{
    NetworkEventKeys.name.name: NetworkEventDefaults.creatorName,
    NetworkEventKeys.creatorVersion.name: devToolsVersion,
  };

  // Build the entries
  final entries = httpRequests.map((e) => HarDataEntry.toJson(e)).toList();

  // Assemble the final HAR object
  return <String, Object?>{
    NetworkEventKeys.log.name: <String, Object?>{
      NetworkEventKeys.version.name: NetworkEventDefaults.logVersion,
      NetworkEventKeys.creator.name: creator,
      NetworkEventKeys.entries.name: entries,
    },
  };
}
