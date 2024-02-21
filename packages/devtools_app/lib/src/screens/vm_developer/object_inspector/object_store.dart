// Copyright 2022 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import '../../../shared/common_widgets.dart';
import '../../../shared/primitives/utils.dart';
import '../../../shared/table/table.dart';
import '../../../shared/table/table_data.dart';
import '../vm_developer_common_widgets.dart';
import '../vm_service_private_extensions.dart';
import 'object_store_controller.dart';

class _EntryColumn extends ColumnData<ObjectStoreEntry> {
  _EntryColumn() : super.wide('Entry');

  @override
  bool get includeHeader => true;

  @override
  String getValue(ObjectStoreEntry dataObject) {
    return dataObject.key;
  }
}

class _ObjectColumn extends ColumnData<ObjectStoreEntry>
    implements ColumnRenderer {
  _ObjectColumn({required this.onTap}) : super.wide('Object');

  final void Function(ObjRef) onTap;

  @override
  bool get includeHeader => true;

  @override
  ObjRef getValue(ObjectStoreEntry dataObject) {
    return dataObject.value;
  }

  @override
  Widget build(
    BuildContext context,
    // ignore: avoid-dynamic, requires refactor.
    data, {
    bool isRowSelected = false,
    bool isRowHovered = false,
    VoidCallback? onPressed,
  }) {
    return VmServiceObjectLink(
      // TODO(srawlins): What type is `data` at runtime? If cast to `int`, no
      // tests fail, but that can't be right...
      // ignore: avoid-dynamic
      object: (data as dynamic).value,
      onTap: onTap,
    );
  }
}

class ObjectStoreViewer extends StatelessWidget {
  ObjectStoreViewer({
    super.key,
    required this.onLinkTapped,
    required this.controller,
  });

  static final _entryColumn = _EntryColumn();
  late final _objectColumn = _ObjectColumn(onTap: onLinkTapped);
  late final _columns = <ColumnData<ObjectStoreEntry>>[
    _entryColumn,
    _objectColumn,
  ];

  final ObjectStoreController controller;
  final void Function(ObjRef) onLinkTapped;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ObjectStore?>(
      valueListenable: controller.selectedIsolateObjectStore,
      builder: (context, objectStore, _) {
        if (objectStore == null) {
          return const CenteredCircularProgressIndicator();
        }
        return FlatTable<ObjectStoreEntry>(
          keyFactory: (item) => Key(item.key),
          columns: _columns,
          data: objectStore.fields.entries.toList(),
          dataKey: 'object-store',
          defaultSortColumn: _entryColumn,
          defaultSortDirection: SortDirection.ascending,
        );
      },
    );
  }
}
