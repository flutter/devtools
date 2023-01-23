// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ExpandType {
  fields(isLive: true),
  liveInboundRefs(isLive: true),
  liveOutboundRefs(isLive: true),
  staticInboundRefs(isLive: false),
  staticOutboundRefs(isLive: false),
  ;

  const ExpandType({required this.isLive});

  final bool isLive;
}
