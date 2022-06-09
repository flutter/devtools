import 'package:collection/collection.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';
import 'path_finder.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<IdentityHashCode>>;

Future<void> setRetainingPaths(
  MemoryController controller,
  List<ObjectReport> reports,
) async {
  final graph = (await controller.snapshotMemory())!;

  final pathAnalyzer = _PathAnalyzer(graph);

  for (var report in reports) {
    report.retainingPath = pathAnalyzer.getPath(report.theIdentityHashCode);
  }
}

class _PathAnalyzer {
  _PathAnalyzer(this.graph) {
    _buildStrictures();
  }

  final HeapSnapshotGraph graph;
  late Retainers _retainers;
  // All objects by hashcode.
  late Map<int, HeapSnapshotObject> _byCode;

  void _buildStrictures() {
    _retainers = {};
    _byCode = {};

    for (var object in graph.objects) {
      if (_shouldSkip(object)) continue;

      _byCode[object.identityHashCode] = object;

      for (var r in object.references) {
        final reference = graph.objects[r];
        if (_shouldSkip(reference)) continue;
        if (reference.identityHashCode == object.identityHashCode) continue;

        if (!_retainers.containsKey(reference.identityHashCode))
          _retainers[reference.identityHashCode] = {};
        _retainers[reference.identityHashCode]!.add(object.identityHashCode);
      }
    }
  }

  String getPath(IdentityHashCode code) {
    final path = findPathFromRoot(_retainers, code);
    if (path == null) throw 'All retainers looped.';
    final result = path.map((i) => _name(_byCode[i]!)).join('/');
    return '/$result/';
  }

  static String _name(HeapSnapshotObject object) {
    return '${object.identityHashCode}-${object.klass.name}';
  }

  bool _shouldSkip(HeapSnapshotObject object) {
    const toSkip = {
      '_WeakReferenceImpl',
      'FinalizerEntry',
      // 'DiagnosticsProperty',
      // '_ElementDiagnosticableTreeNode',
      // '_InspectorReferenceData',
      // 'DebugCreator',
      // '_WidgetTicker',
    };

    return toSkip.contains(object.klass.name);
  }
}
