import 'package:collection/collection.dart';
import 'package:memory_tools/model.dart';
import 'package:vm_service/vm_service.dart';

import '../../memory_controller.dart';

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

class _PathItem {
  _PathItem(this.options);

  final List<IdentityHashCode> options;
  int _index = 0;

  IdentityHashCode get selection => options[_index];
  bool get canChange => _index < options.length - 1;
  void change() => _index++;
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
      if (_shouldSkip(object.identityHashCode)) continue;

      _byCode[object.identityHashCode] = object;

      for (var r in object.references) {
        final reference = graph.objects[r];
        if (_shouldSkip(reference.identityHashCode)) continue;
        if (reference.identityHashCode == object.identityHashCode) continue;

        if (!_retainers.containsKey(reference.identityHashCode))
          _retainers[reference.identityHashCode] = {};
        _retainers[reference.identityHashCode]!.add(object.identityHashCode);
      }
    }
    _assertThereAreRoots();
  }

  void _assertThereAreRoots() {
    var rootCount = 0;
    for (var object in graph.objects) {
      if (_retainers[object.identityHashCode]?.isEmpty != false) rootCount++;
    }
    print('!!!!!!!! $rootCount roots out of ${graph.objects.length} objects');
    assert(rootCount > 0);
  }

  String getPath(IdentityHashCode code) {
    final path = [
      _PathItem([code])
    ];
    IdentityHashCode current = code;

    while (_retainers[current]?.isNotEmpty == true) {
      if (path.length > 1000) throw 'Too large path.';

      if (_retainers[current]!.length > 1) {
        final list = _retainers[current]!
            .toList()
            .map((e) => _name(_byCode[e]!))
            .join(', ');
        print(list);
      }

      final options = _retainers[current]!.where((retainer) {
        final loop =
            path.firstWhereOrNull((element) => element.selection == retainer);
        return loop == null;
      }).toList();

      if (options.isNotEmpty) {
        path.insert(0, _PathItem(options));
      } else {
        int toChange = 0;
        while (!path[toChange].canChange && toChange < path.length - 1) {
          toChange++;
        }
        assert(path[toChange].canChange, 'All retainers looped the path.');
        path[toChange].change();
        path.removeRange(0, toChange);
      }

      current = path.first.selection;

      assert(
        current != code,
        'loop found',
      );
      assert(!_shouldSkip(path.first.selection));
    }

    final result = path.map((e) => _name(_byCode[e.selection]!)).join('/');
    return '/$result/';
  }

  static String _name(HeapSnapshotObject object) {
    return '${object.identityHashCode}-${object.klass.name}';
  }

  bool _shouldSkip(IdentityHashCode code) {
    //if (object.identityHashCode == 0) return true;
    final object = _byCode[code]!;

    const toSkip = {
      '_WeakReferenceImpl',
      'FinalizerEntry',
      // 'DiagnosticsProperty',
      // '_ElementDiagnosticableTreeNode',
      // '_InspectorReferenceData',
      // 'DebugCreator',
      // '_WidgetTicker',
    };
    if (toSkip.contains(object.klass.name)) return true;

    return false;
  }
}
