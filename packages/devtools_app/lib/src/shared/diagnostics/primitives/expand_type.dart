// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum ExpandType {
  /// Members of class or items in lists/maps.
  members(isLive: true),

  /// Root for references.
  refRoot(isLive: true),

  // /// Live references.
  // liveRefRoot(isLive: true),

  // /// Live inbound references.
  // liveInboundRefs(isLive: true),

  // liveOutboundRefs(isLive: true),
  staticRefRoot(isLive: false),
  staticInboundRefs(isLive: false),
  staticOutboundRefs(isLive: false),
  ;

  const ExpandType({required this.isLive});

  /// Live if true, static if false.
  final bool isLive;
}
