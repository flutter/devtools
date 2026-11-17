// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

import 'package:dtd/dtd.dart';
import 'package:meta/meta.dart';

// ignore: unused-code, false positive.
const _fileUriPrefix = 'file://';

/// Attempts to detect the package root of [fileUriString], which is expected to
/// be a proper file URI (i.e. starts with "file://").
///
/// This method first tries to use the Dart Tooling Daemon to walk the
/// directory structure of [fileUriString] and look for the package root; we
/// consider a directory to be a package root if it contains the `.dart_tool`
/// directory.
///
/// If we cannot find the package root using the Dart Tooling Daemon, we use the
/// heuristic that a Dart executable within a Dart package should reside in one
/// of the following top-level folders:
///
/// * lib
/// * bin
/// * integration_test
/// * test
/// * benchmark
/// * example
///
/// The URI returned will be a file URI String and will NOT have a trailing
/// slash.
Future<String> packageRootFromFileUriString(
  String fileUriString, {
  DartToolingDaemon? dtd,
  @visibleForTesting bool throwOnDtdSearchFailed = false,
}) async {
  assert(
    fileUriString.startsWith(_fileUriPrefix),
    'Invalid URI format: expected URI String to start with "$_fileUriPrefix", '
    'but instead, got $fileUriString.',
  );

  if (dtd != null) {
    // Use type [Object] so we can store exceptions of all types.
    Object? exception;

    var uri = Uri.parse(fileUriString);
    while (uri.pathSegments.length > 1) {
      // Remove the last path segment.
      uri = uri.replace(
        pathSegments: uri.pathSegments.sublist(0, uri.pathSegments.length - 1),
      );
      try {
        final directoryContents = await dtd.listDirectoryContents(uri);
        final containsDartToolDirectory = (directoryContents.uris ?? const [])
            .any((uri) => uri.path.endsWith('.dart_tool/'));
        if (containsDartToolDirectory) {
          final uriAsString = uri.toString();
          return _assertUriFormatAndReturn(
            uriAsString.endsWith('/')
                ? uriAsString.substring(0, uriAsString.length - 1)
                : uriAsString,
          );
        }
      } catch (e) {
        // Fail gracefully on exception, and proceed to using heuristic below.
        exception = e;
        break;
      }
    }
    if (throwOnDtdSearchFailed) {
      throw Exception(
        'Expected DTD to detect the package root for '
        '$fileUriString, but it failed'
        '${exception != null ? ' with exception: $exception' : '.'}',
      );
    }
  }

  // If we do not have access to DTD or if we failed to detect the package root
  // by walking the directory structure, default to using a regexp heuristic.
  final directoryRegExp = RegExp(
    r'\/(lib|bin|integration_test|test|benchmark|example)\/.+\.dart',
  );
  final directoryIndex = fileUriString.lastIndexOf(directoryRegExp);
  if (directoryIndex != -1) {
    fileUriString = fileUriString.substring(0, directoryIndex);
  }
  return _assertUriFormatAndReturn(fileUriString);
}

String _assertUriFormatAndReturn(String uriString) {
  assert(
    uriString.startsWith(_fileUriPrefix),
    'Invalid URI format: should be a file URI.',
  );
  assert(
    !uriString.endsWith('/'),
    'Invalid URI format: should not have a trailing slash.',
  );
  return uriString;
}

/// Returns whether [uri] is a valid local `file:` URI without an authority,
/// query, fragment, or dot path traversal segments.
///
/// Requiring an empty authority rejects remote hosts, ports, user info, and
/// Windows UNC paths (e.g. `file://server/share/...`). Requiring an absolute
/// path without query or fragment components ensures [Uri.toFilePath] will not
/// throw an [UnsupportedError].
bool isValidLocalFileUri(Uri uri) {
  if (uri.scheme != 'file' ||
      uri.authority.isNotEmpty ||
      !uri.hasAbsolutePath ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  for (final segment in uri.pathSegments) {
    for (final part in segment.split(r'\')) {
      if (part == '.' || part == '..') return false;
    }
  }
  return true;
}

/// Returns whether [uriString] is a `file://` URI string without dot-segment
/// traversal (`.` or `..`) that parses as a valid local `file:` URI via
/// [isValidLocalFileUri].
bool isValidLocalFileUriString(String? uriString) {
  if (uriString == null || !uriString.startsWith(_fileUriPrefix)) {
    return false;
  }
  final uri = Uri.tryParse(uriString);
  if (uri == null || !isValidLocalFileUri(uri)) {
    return false;
  }
  // Check raw segments before `Uri.tryParse` normalizes `.` and `..` away.
  final rawPath = uriString.substring(_fileUriPrefix.length);
  for (final segment in rawPath.split('/')) {
    if (segment == '.' || segment == '..') return false;
    try {
      final decoded = Uri.decodeComponent(segment);
      for (final part in decoded.split(r'\')) {
        if (part == '.' || part == '..') return false;
      }
    } on ArgumentError {
      return false;
    }
  }
  return true;
}
