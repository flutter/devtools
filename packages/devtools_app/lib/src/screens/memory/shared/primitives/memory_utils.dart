// Copyright 2022 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file or at https://developers.google.com/open-source/licenses/bsd.

/// @docImport '../../../../shared/memory/class_name.dart';
library;

import 'package:devtools_app_shared/service.dart' show RootInfo;
import 'package:vm_service/vm_service.dart';

import '../../../../shared/globals.dart';

/// Memory screen specific information derived from the [RootInfo] of the
/// connected app.
extension RootInfoMemoryExtension on RootInfo {
  /// The prefix of the URIs of the libraries that belong to the root package of
  /// the connected app, or `null` if the root library is unknown.
  ///
  /// The Memory screen passes this prefix as `rootPackage` to
  /// [HeapClassName.classType], which classifies a class as
  /// [ClassType.rootPackage] (a "project" class) if the URI of its library
  /// starts with the prefix.
  ///
  /// For the root library `package:my_app/main.dart`, the prefix is
  /// `package:my_app`.
  ///
  /// Unlike [RootInfo.package], the prefix is not `null` when the root library
  /// is not a `package:` URI. For example, the root library of a Dart CLI app
  /// started with `dart run` is a `file:` URI like `file:///app/bin/main.dart`,
  /// and the prefix is `file:`. Without a prefix, the classes defined in the
  /// files of such an app would be classified as [ClassType.runtime], which
  /// disables evaluating them in the live app.
  String? get rootPackagePrefix {
    final library = this.library;
    if (library == null) return null;

    final slashIndex = library.indexOf('/');
    return slashIndex == -1 ? library : library.substring(0, slashIndex);
  }
}

Future<HeapSnapshotGraph?> snapshotMemoryInSelectedIsolate() async {
  final isolate =
      serviceConnection.serviceManager.isolateManager.selectedIsolate.value;
  if (isolate == null) return null;
  return await serviceConnection.serviceManager.service?.getHeapSnapshotGraph(
    isolate,
    decodeExternalProperties: false,
    decodeObjectData: false,
  );
}

String? get selectedIsolateName =>
    serviceConnection.serviceManager.isolateManager.selectedIsolate.value?.name;
