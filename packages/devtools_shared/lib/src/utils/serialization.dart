// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

typedef FromJson<T> = T Function(Map<String, dynamic> json);

/// Mixin to declare a class as serializable.
///
/// Classes that implement this mixin should also implement a `fromJson` factory
/// constructor.
/// See https://docs.flutter.dev/data-and-backend/serialization/json#serializing-json-inside-model-classes.
mixin Serializable {
  Map<String, Object?> toJson();
}

/// Deserializes an object if it is serialized.
// ignore: avoid-dynamic, serialization is exception for the rule.
T deserialize<T>(dynamic json, FromJson<T> deserializer) {
  if (json is T) return json;
  return deserializer(json);
}

/// Deserializes an object if it is serialized.
///
/// Returns null if the json is null.
// ignore: avoid-dynamic, serialization is exception for the rule.
T? deserializeNullable<T>(dynamic json, FromJson<T> deserializer) {
  if (json == null) return null;
  return deserialize(json, deserializer);
}
