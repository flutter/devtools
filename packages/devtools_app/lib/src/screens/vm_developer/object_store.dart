import 'package:flutter/widgets.dart';
import 'package:vm_service/vm_service.dart';

import '../../primitives/utils.dart';
import '../../shared/common_widgets.dart';
import '../../shared/table.dart';
import '../../shared/table_data.dart';
import 'object_store_controller.dart';
import 'vm_developer_common_widgets.dart';
import 'vm_service_private_extensions.dart';

class _Entry extends ColumnData<ObjectStoreEntry> {
  _Entry() : super.wide('Entry');

  @override
  bool get includeHeader => true;

  @override
  String getValue(ObjectStoreEntry dataObject) {
    return dataObject.key;
  }
}

class _Object extends ColumnData<ObjectStoreEntry> implements ColumnRenderer {
  _Object({required this.onTap}) : super.wide('Object');

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
    data, {
    bool isRowSelected = false,
    VoidCallback? onPressed,
  }) {
    return VmServiceObjectLink<ObjRef>(
      object: data.value,
      onTap: onTap,
    );
  }
}

class ObjectStoreViewer extends StatelessWidget {
  ObjectStoreViewer({
    required this.onLinkTapped,
    required this.controller,
  });

  final _entryColumn = _Entry();
  late final _objectColumn = _Object(onTap: onLinkTapped);
  late final _columns = <ColumnData<ObjectStoreEntry>>[
    _entryColumn,
    _objectColumn,
  ];

  final ObjectStoreController controller;
  final void Function(ObjRef) onLinkTapped;

  @override
  Widget build(BuildContext context) {
    return OutlineDecoration(
      child: ValueListenableBuilder<ObjectStore?>(
        valueListenable: controller.selectedIsolateObjectStore,
        builder: (context, objectStore, _) {
          if (objectStore == null) {
            return const CenteredCircularProgressIndicator();
          }
          return FlatTable<ObjectStoreEntry>(
            keyFactory: (item) => Key(item.key),
            columns: _columns,
            data: objectStore.fields.entries.toList(),
            sortColumn: _entryColumn,
            sortDirection: SortDirection.ascending,
            onItemSelected: (_) => null,
          );
        },
      ),
    );
  }
}
