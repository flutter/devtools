// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

enum AppStatus {
  leakTrackingNotSupported,
  noCommunicationsRecieved,
  unsupportedProtocolVersion,
  leakTrackingStarted,
  leaksFound,
}

/// We may use https://pub.dev/packages/vendor to support previous versions of leak_tracker.
const supportedLeakTrackingProtocols = <String>{'1'};
