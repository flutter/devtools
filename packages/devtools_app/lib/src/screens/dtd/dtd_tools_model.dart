// Copyright 2025 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:devtools_app_shared/utils.dart';
import 'package:flutter/foundation.dart';

/// Base class for a feature controller on the `DTDToolsScreen`.
abstract class FeatureController extends DisposableController
    with AutoDisposeControllerMixin {
  @override
  @mustCallSuper
  void init();
}

/// Describes a DTD service method.
///
/// [service] may be null if this service method is a first party service
/// method registered by DTD or by a DTD-internal service.
class DtdServiceMethod implements Comparable<DtdServiceMethod> {
  const DtdServiceMethod({
    required this.service,
    required this.method,
    this.capabilities,
  });

  final String? service;
  final String method;
  final Map<String, Object?>? capabilities;

  String get displayName => [service, method].nonNulls.join('.');

  @override
  bool operator ==(Object other) {
    return other is DtdServiceMethod &&
        other.service == service &&
        other.method == method;
  }

  @override
  int get hashCode => Object.hash(service, method);

  @override
  int compareTo(DtdServiceMethod other) {
    return displayName.compareTo(other.displayName);
  }
}
