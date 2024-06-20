// Copyright 2024 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Events received over the VM Service from the Flutter framework.
///
/// This is a class instead of an enum so that the event name values can be
/// used in constant expressions.
abstract class FlutterEvent {
  static const error = 'Flutter.Error';
  static const frame = 'Flutter.Frame';
  static const firstFrame = 'Flutter.FirstFrame';
  static const frameworkInitialization = 'Flutter.FrameworkInitialization';
  static const imageSizesForFrame = 'Flutter.ImageSizesForFrame';
  static const navigation = 'Flutter.Navigation';
  static const print = 'Flutter.Print';
  static const rebuiltWidgets = 'Flutter.RebuiltWidgets';
  static const serviceExtensionStateChanged =
      'Flutter.ServiceExtensionStateChanged';
}

/// Events received over the VM Service from one the running developer services
/// (DDS, VM Service, etc.).
///
/// This is a class instead of an enum so that the event name values can be
/// used in constant expressions.
abstract class DeveloperServiceEvent {
  static const httpTimelineLoggingStateChange =
      'HttpTimelineLoggingStateChange';
  static const socketProfilingStateChange = 'SocketProfilingStateChange';
}
