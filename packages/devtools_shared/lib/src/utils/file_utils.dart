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

/// Error description for invalid local `file://` URIs.
const invalidLocalFileUriMessage =
    'must be an absolute file:// URI with no host, query, or fragment.';

/// Returns whether [uri] is a valid local `file:` URI without an authority,
/// query, fragment, or null bytes, and can be converted to a local file path.
///
/// Requiring an empty authority rejects remote hosts, ports, user info, and
/// Windows UNC paths (e.g. `file://server/share/...`). Checking
/// [Uri.toFilePath] ensures callers can convert [uri] without triggering an
/// [UnsupportedError] or [FormatException].
bool isValidLocalFileUri(Uri uri) {
  if (uri.scheme != 'file' ||
      uri.authority.isNotEmpty ||
      !uri.hasAbsolutePath ||
      uri.hasQuery ||
      uri.hasFragment) {
    return false;
  }
  try {
    final filePath = uri.toFilePath();
    return !filePath.contains('\x00');
  } catch (_) {
    return false;
  }
}

/// Returns whether [uriString] is a `file://` URI string that parses as a valid
/// local `file:` URI via [isValidLocalFileUri].
bool isValidLocalFileUriString(String? uriString) {
  if (uriString == null || !uriString.startsWith(_fileUriPrefix)) {
    return false;
  }
  final uri = Uri.tryParse(uriString);
  return uri != null && isValidLocalFileUri(uri);
}
