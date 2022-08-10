// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../../shared/theme.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to library objects in the Dart VM.
class VmLibraryDisplay extends StatelessWidget {
  const VmLibraryDisplay({
    required this.library,
  });

  final LibraryObject library;

  @override
  Widget build(BuildContext context) {
    final dependencies = library.obj.dependencies;
    return VmObjectDisplayBasicLayout(
      object: library,
      generalDataRows: _libraryDataRows(library),
      expandableWidgets: [
        if (dependencies != null)
          LibraryDependencies(dependencies: dependencies)
      ],
    );
  }

  /// Generates a list of key-value pairs (map entries) containing the general
  /// information of the library object [library].
  List<MapEntry<String, WidgetBuilder>> _libraryDataRows(
    LibraryObject library,
  ) {
    return [
      ...vmObjectGeneralDataRows(library),
      selectableTextBuilderMapEntry(
        'URI',
        (library.obj.uri?.isEmpty ?? false)
            ? library.script?.uri
            : library.obj.uri,
      ),
      selectableTextBuilderMapEntry(
        'VM Name',
        library.vmName,
      ),
    ];
  }
}

/// An expandable tile displaying a list of library dependencies
class LibraryDependencies extends StatelessWidget {
  const LibraryDependencies({
    required this.dependencies,
  });

  final List<LibraryDependency> dependencies;

  List<Row> dependencyRows(BuildContext context) {
    final textStyle = Theme.of(context).fixedFontStyle;

    return <Row>[
      for (final dep in dependencies)
        Row(
          children: [
            Flexible(
              child: SelectableText(
                dependencyDescription(dep),
                style: textStyle,
              ),
            ),
          ],
        )
    ];
  }

  String dependencyDescription(LibraryDependency dependency) {
    final description = StringBuffer();
    void addSpace() => description.write(description.isEmpty ? '' : ' ');

    final isImport = dependency.isImport;
    if (isImport != null) {
      description.write(isImport ? 'import' : 'export');
    }

    addSpace();

    description.write(
      dependency.target?.name ?? dependency.target?.uri ?? '<Library name>',
    );

    final prefix = dependency.prefix;

    if (prefix != null && prefix.isNotEmpty) {
      addSpace();
      description.write('as $prefix');
    }
    if (dependency.isDeferred == true) {
      addSpace();
      description.write('deferred');
    }

    return description.toString();
  }

  @override
  Widget build(BuildContext context) {
    return VmExpansionTile(
      title: 'Dependencies (${dependencies.length})',
      children: prettyRows(
        context,
        dependencyRows(context),
      ),
    );
  }
}
