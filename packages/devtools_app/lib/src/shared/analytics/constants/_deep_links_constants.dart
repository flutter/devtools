// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

enum AnalyzeFlutterProject {
  /// A valid flutter project has been selected.
  flutterProjectSelected,

  /// Used for recording the time spends in loading Android variants.
  loadVariants,

  /// Used for recording the time spends in loading App Links.
  loadAppLinks,

  /// App Links are loaded and there is at least one link.
  flutterHasAppLinks,

  /// App Links are loaded and there is at least one link.
  flutterNoAppLink,

  /// App Links can't be loaded.
  ///
  /// One possible cause is that the project can't be compiled due to dart
  /// error or gradle build error.
  flutterAppLinkLoadingError,
}
