// Copyright 2018 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// Reference to a Dart object.
///
/// This class is similar to the Observatory protocol InstanceRef with the
/// difference that InspectorInstanceRef objects do not expire and all
/// instances of the same Dart object are guaranteed to have the same
/// InspectorInstanceRef id. The tradeoff is the consumer of
/// InspectorInstanceRef objects is responsible for managing their lifecycles.
class InspectorInstanceRef {
  const InspectorInstanceRef(this.id);

  @override
  bool operator ==(Object other) {
    if (other is InspectorInstanceRef) {
      return id == other.id;
    }
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '$id';

  final String? id;
}
