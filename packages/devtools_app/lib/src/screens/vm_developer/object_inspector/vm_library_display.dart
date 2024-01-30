// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:devtools_app_shared/ui.dart';
import 'package:flutter/material.dart';
import 'package:vm_service/vm_service.dart';

import '../vm_developer_common_widgets.dart';
import 'object_inspector_view_controller.dart';
import 'vm_object_model.dart';

/// A widget for the object inspector historyViewport displaying information
/// related to library objects in the Dart VM.
class VmLibraryDisplay extends StatelessWidget {
  const VmLibraryDisplay({
    super.key,
    required this.controller,
    required this.library,
  });

  final ObjectInspectorViewController controller;
  final LibraryObject library;

  @override
  Widget build(BuildContext context) {
    final dependencies = library.obj.dependencies;
    return ObjectInspectorCodeView(
      codeViewController: controller.codeViewController,
      script: library.scriptRef!,
      object: library.obj,
      child: VmObjectDisplayBasicLayout(
        controller: controller,
        object: library,
        generalDataRows: _libraryDataRows(library),
        expandableWidgets: [
          if (dependencies != null)
            LibraryDependencies(dependencies: dependencies),
        ],
      ),
    );
  }

  /// Generates a list of key-value pairs (map entries) containing the general
  /// information of the library object [library].
  List<MapEntry<String, WidgetBuilder>> _libraryDataRows(
    LibraryObject library,
  ) {
    return [
      ...vmObjectGeneralDataRows(
        controller,
        library,
      ),
      serviceObjectLinkBuilderMapEntry(
        controller: controller,
        key: 'URI',
        preferUri: true,
        object:
            (library.obj.uri?.isEmpty ?? false) ? library.script! : library.obj,
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
    super.key,
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
                dep.description,
                style: textStyle,
              ),
            ),
          ],
        ),
    ];
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

extension LibraryDependencyExtension on LibraryDependency {
  String get description {
    final description = StringBuffer();
    void addSpace() => description.write(description.isEmpty ? '' : ' ');

    final libIsImport = isImport;
    if (libIsImport != null) {
      description.write(libIsImport ? 'import' : 'export');
    }

    addSpace();

    description.write(
      target?.name ?? target?.uri ?? '<Library name>',
    );

    final libPrefix = prefix;

    if (libPrefix != null && libPrefix.isNotEmpty) {
      addSpace();
      description.write('as $libPrefix');
    }

    if (isDeferred == true) {
      addSpace();
      description.write('deferred');
    }

    return description.toString();
  }
}
