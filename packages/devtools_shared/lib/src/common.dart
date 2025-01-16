// Copyright 2024 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// Describes an instance of the Dart Tooling Daemon.
@Deprecated('Use DtdInfo instead')
typedef DTDConnectionInfo = ({String? uri, String? secret});

/// Information about a Dart Tooling Daemon instance.
class DtdInfo {
  DtdInfo(
    this.localUri, {
    Uri? exposedUri,
    this.secret,
  }) : exposedUri = exposedUri ?? localUri;

  /// The URI for connecting to DTD from the backend.
  ///
  /// This is usually a `http://localhost/` address that is accessible to tools
  /// running in the same location as the DTD process. It may NOT be accessible
  /// to frontends that run in another location - for example the DevTools
  /// frontend running in a browser (or embedded in an IDE) in a remote/web IDE
  /// session.
  final Uri localUri;

  /// The exposed URI for connecting to DTD from the frontend.
  ///
  /// In a remote session, this can be an address provided by the hosting
  /// infrastructure/proxy that tunnels through to the backend running the DTD
  /// process which might look like `https://foo-123.cloud-ide.foo/`.
  ///
  /// For a non-remote session, this will be the same value as [localUri].
  final Uri exposedUri;

  /// The secret token that allows calling privileged DTD APIs.
  ///
  /// This may not always be available if DTD was spawned by another process
  /// and it should never be shared with external code.
  final String? secret;
}
