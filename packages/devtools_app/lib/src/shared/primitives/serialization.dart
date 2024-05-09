// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

typedef FromJson<T> = T Function(Map<String, dynamic> json);

// ignore: avoid-dynamic, serialization is exception for the rule.
T deserialize<T>(dynamic json, FromJson<T> deserializer) {
  if (json is T) return json;
  return deserializer(json);
}
