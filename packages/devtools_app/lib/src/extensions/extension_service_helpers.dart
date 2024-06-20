// Copyright 2023 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/utils.dart';
import 'package:devtools_shared/devtools_extensions.dart';
import 'package:devtools_shared/devtools_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// De-duplicates extensions by ignoring all that are not the latest version
/// when there are duplicates.
void deduplicateExtensionsAndTakeLatest(
  List<DevToolsExtensionConfig> extensions, {
  required void Function(DevToolsExtensionConfig ext, {required bool ignore})
      onSetIgnored,
  Logger? logger,
  String extensionType = '',
}) {
  final deduped = <String>{};
  for (final ext in extensions) {
    if (deduped.contains(ext.name)) continue;
    deduped.add(ext.name);

    // This includes [ext] itself.
    final matchingExtensions = extensions.where((e) => e.name == ext.name);
    if (matchingExtensions.length > 1) {
      logger?.fine(
        'detected duplicate $extensionType extensions for ${ext.name}',
      );

      // Ignore all matching extensions and then mark the [latest] as
      // unignored after the loop is finished.
      var latest = ext;
      for (final ext in matchingExtensions) {
        onSetIgnored(ext, ignore: true);
        latest = takeLatestExtension(latest, ext);
      }
      onSetIgnored(latest, ignore: false);

      logger?.fine(
        'ignored ${matchingExtensions.length - 1} duplicate $extensionType '
        '${pluralize('extension', matchingExtensions.length - 1)} in favor of '
        '${latest.identifier} at ${latest.devtoolsOptionsUri}',
      );
    } else {
      logger?.fine(
        'no duplicates found for $extensionType extension ${ext.name}',
      );
    }
  }
}

/// Compares the versions of extension configurations [a] and [b] and returns
/// the extension configuration with the latest version, following semantic
/// versioning rules.
@visibleForTesting
DevToolsExtensionConfig takeLatestExtension(
  DevToolsExtensionConfig a,
  DevToolsExtensionConfig b,
) {
  bool exceptionParsingA = false;
  bool exceptionParsingB = false;
  SemanticVersion? versionA;
  SemanticVersion? versionB;
  try {
    versionA = SemanticVersion.parse(a.version);
  } catch (_) {
    exceptionParsingA = true;
  }

  try {
    versionB = SemanticVersion.parse(b.version);
  } catch (_) {
    exceptionParsingB = true;
  }

  if (exceptionParsingA || exceptionParsingB) {
    if (exceptionParsingA) {
      return b;
    }
    return a;
  }

  final versionCompare = versionA!.compareTo(versionB!);
  return versionCompare >= 0 ? a : b;
}
