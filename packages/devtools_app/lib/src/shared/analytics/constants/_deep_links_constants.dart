// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of '../constants.dart';

enum AnalyzeFlutterProject {
  /// A valid flutter project has been selected.
  flutterProjectSelected,

  /// A invalid flutter project has been selected.
  ///
  /// This can be a result of the user didn't select a Flutter project or
  /// the their Android sub project threw error when parsing.
  flutterInvalidProjectSelected,

  /// Used for recording the time spent in loading Android variants.
  loadVariants,

  /// Used for recording the time spent in loading iOS build options.
  loadIosBuildOptions,

  /// Used for recording the time spent in loading App Links.
  loadAppLinks,

  /// Used for recording the time spent in loading iOS Links.
  loadIosLinks,

  /// App Links are loaded and there is at least one link.
  flutterHasAppLinks,

  /// There is no app link in the project.
  flutterNoAppLink,

  /// App Links can't be loaded.
  ///
  /// One possible cause is that the project can't be compiled due to dart
  /// error or gradle build error.
  flutterAppLinkLoadingError,
}
