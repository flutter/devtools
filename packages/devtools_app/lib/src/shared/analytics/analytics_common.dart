// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Code in this file should be able to be imported by both web and dart:io
// dependent libraries.

/// Base class for all screen metrics classes.
///
/// Create a subclass of this class to store custom metrics for a screen. All
/// subclasses are expected to add custom metrics as fields. For example:
///
/// ```dart
/// class MyScreenAnalyticsMetrics extends ScreenAnalyticsMetrics {
///   const MyScreenAnalyticsMetrics({this.myMetric1, this.myMetric2});
///
///   final int myMetric1;
///
///   final String myMetric2;
/// }
/// ```
///
/// Then, add your fields to the [GtagEventDevTools] factory constructor and add
/// a corresponding getter in the class.
abstract class ScreenAnalyticsMetrics {}
