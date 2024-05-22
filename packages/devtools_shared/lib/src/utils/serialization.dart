// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

typedef FromJson<T> = T Function(Map<String, dynamic> json);

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
  if (json is T) return json;
  return deserializer(json);
}
