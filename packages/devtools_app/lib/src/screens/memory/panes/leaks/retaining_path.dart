import 'package:collection/collection.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';

typedef IdentityHashCode = int;
typedef Retainers = Map<IdentityHashCode, Set<HeapSnapshotObject>>;

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

class PathItem {
  PathItem(this.options);

  final List<HeapSnapshotObject> options;
  int _index = 0;

  HeapSnapshotObject get selection => options[_index];
  bool get canChange => _index < options.length - 1;
  void change() => _index++;
}

class _PathAnalyzer {
  _PathAnalyzer(this.graph) {
    _buildStrictures();
  }

  final HeapSnapshotGraph graph;
  late Retainers retainers;
  late Map<int, HeapSnapshotObject> byCode;

  void _buildStrictures() {
    retainers = {};
    byCode = {};

    for (var object in graph.objects) {
      if (_shouldSkip(object)) continue;

      byCode[object.identityHashCode] = object;

      for (var r in object.references) {
        final reference = graph.objects[r];
        if (_shouldSkip(reference)) continue;
        if (reference.identityHashCode == object.identityHashCode) continue;

        if (!retainers.containsKey(reference.identityHashCode))
          retainers[reference.identityHashCode] = {};
        retainers[reference.identityHashCode]!.add(object);
      }
    }
  }

  String getPath(IdentityHashCode code) {
    final path = [
      PathItem([byCode[code]!])
    ];
    IdentityHashCode current = code;

    while (retainers[current]?.isNotEmpty == true) {
      if (path.length > 1000) throw 'Too large path.';

      if (retainers[current]!.length > 1) {
        final list =
            retainers[current]!.toList().map((e) => _name(e)).join(', ');
        print(list);
      }

      final options = retainers[current]!.where((retainer) {
        final loop = path.firstWhereOrNull((element) =>
            element.selection.identityHashCode == retainer.identityHashCode);
        return loop == null;
      }).toList();

      if (options.isNotEmpty) {
        path.insert(0, PathItem(options));
      } else {
        int toChange = 0;
        while (!path[toChange].canChange && toChange < path.length - 1) {
          toChange++;
        }
        assert(path[toChange].canChange, 'All retainers looped the path.');
        path[toChange].change();
        path.removeRange(0, toChange);
      }

      current = path.first.selection.identityHashCode;

      assert(
        current != code,
        'loop found',
      );
      assert(!_shouldSkip(path.first.selection));
    }

    final result = path.map((e) => _name(e.selection)).join('/');
    return '/$result/';
  }

  static String _name(HeapSnapshotObject object) {
    return '${object.identityHashCode}-${object.klass.name}';
  }

  static bool _shouldSkip(HeapSnapshotObject object) {
    if (object.identityHashCode == 0) return true;

    const toSkip = {
      '_WeakReferenceImpl',
      'FinalizerEntry',
      'DiagnosticsProperty',
      '_ElementDiagnosticableTreeNode',
      '_InspectorReferenceData',
      'DebugCreator',
      '_WidgetTicker',
    };
    if (toSkip.contains(object.klass.name)) return true;

    return false;
  }
}
