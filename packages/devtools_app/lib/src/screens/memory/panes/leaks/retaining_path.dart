import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';

Future<void> setRetainingPaths(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final byCode = Map<int, ObjectReport>.fromIterable(
    reports,
    key: (r) => r.theIdentityHashCode,
    value: (r) => r,
  );
  final graph = (await controller.snapshotMemory())!;

  for (var object in graph.objects) {
    if (byCode.containsKey(object.identityHashCode)) {
      byCode[object.identityHashCode]!.retainingPath = _getPath(graph, object);
    }
  }
}

String _getPath(HeapSnapshotGraph graph, HeapSnapshotObject object) {
  final path = [object];

  while (path.last.references.isNotEmpty) {
    path.insert(0, graph.objects[path.last.references[0]]);
    assert(
      path.last.identityHashCode != path.first.identityHashCode,
      'loop found',
    );
    assert(!_isWeak(path.first.runtimeType));
  }

  String result = path.map((e) => e.identityHashCode.toString()).join('/');
  return '/$result/';
}

bool _isWeak(Type type) {
  return type.toString().contains(new RegExp(r'weak', caseSensitive: false));
}
