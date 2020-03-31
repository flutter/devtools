import 'package:vm_service/vm_service.dart';

HeapGraph convertHeapGraph(HeapSnapshotGraph graph) {
  final HeapGraphClassSentinel classSentinel = HeapGraphClassSentinel();
  final List<HeapGraphClassActual> classes =
      List<HeapGraphClassActual>(graph.classes.length);
  for (int i = 0; i < graph.classes.length; i++) {
    final HeapSnapshotClass c = graph.classes[i];
    classes[i] = HeapGraphClassActual(c);
  }

  final HeapGraphElementSentinel elementSentinel = HeapGraphElementSentinel();
  final List<HeapGraphElementActual> elements =
      List<HeapGraphElementActual>(graph.objects.length);
  for (int i = 0; i < graph.objects.length; i++) {
    final HeapSnapshotObject o = graph.objects[i];
    elements[i] = HeapGraphElementActual(o);
  }

  for (int i = 0; i < graph.objects.length; i++) {
    final HeapSnapshotObject o = graph.objects[i];
    final HeapGraphElementActual converted = elements[i];
    if (o.classId == 0) {
      converted.theClass = classSentinel;
    } else {
if (o.classId == 4289 || o.classId == 4290) {
  print(">>>>> STOP converting 4289 or 4290");
}
      converted.theClass = classes[o.classId - 1];
    }
    converted.referencesFiller = () {
      for (int refId in o.references) {
        HeapGraphElement ref;
        if (refId == 0) {
          ref = elementSentinel;
        } else {
          ref = elements[refId - 1];
        }
        converted.references.add(ref);
      }
    };
  }

  return HeapGraph(classSentinel, classes, elementSentinel, elements);
}

class HeapGraph {
  HeapGraph(
    this.classSentinel,
    this.classes,
    this.elementSentinel,
    this.elements,
  );

  final HeapGraphClassSentinel classSentinel;
  final List<HeapGraphClassActual> classes;
  final HeapGraphElementSentinel elementSentinel;
  final List<HeapGraphElementActual> elements;
}

abstract class HeapGraphElement {
  /// Outbound references, i.e. this element points to elements in this list.
  List<HeapGraphElement> _references;
  void Function() referencesFiller;
  List<HeapGraphElement> get references {
    if (_references == null && referencesFiller != null) {
      _references = [];
      referencesFiller();
    }
    return _references;
  }

  String getPrettyPrint(Map<Uri, Map<String, List<String>>> prettyPrints) {
    if (this is HeapGraphElementActual) {
      final HeapGraphElementActual me = this;
      if (me.theClass.toString() == '_OneByteString') {
        return '"${me.origin.data}"';
      }
      if (me.theClass.toString() == '_SimpleUri') {
        return '_SimpleUri['
            "${me.getField("_uri").getPrettyPrint(prettyPrints)}]";
      }
      if (me.theClass.toString() == '_Uri') {
        return "_Uri[${me.getField("scheme").getPrettyPrint(prettyPrints)}:"
            "${me.getField("path").getPrettyPrint(prettyPrints)}]";
      }
      if (me.theClass is HeapGraphClassActual) {
        final HeapGraphClassActual c = me.theClass;
        final Map<String, List<String>> classToFields =
            prettyPrints[c.libraryUri];
        if (classToFields != null) {
          final List<String> fields = classToFields[c.name];
          if (fields != null) {
            return '${c.name}[' +
                fields.map((field) {
                  return '$field: '
                      '${me.getField(field)?.getPrettyPrint(prettyPrints)}';
                }).join(', ') +
                ']';
          }
        }
      }
    }
    return toString();
  }
}

class HeapGraphElementSentinel extends HeapGraphElement {
  @override
  String toString() => 'HeapGraphElementSentinel';
}

class HeapGraphElementActual extends HeapGraphElement {
  HeapGraphElementActual(this.origin);

  final HeapSnapshotObject origin;
  HeapGraphClass theClass;

  HeapGraphElement getField(String name) {
    if (theClass is HeapGraphClassActual) {
      final HeapGraphClassActual c = theClass;
      for (HeapSnapshotField field in c.origin.fields) {
        if (field.name == name) {
          return references[field.index];
        }
      }
    }
    return null;
  }

  List<MapEntry<String, HeapGraphElement>> getFields() {
    final List<MapEntry<String, HeapGraphElement>> result = [];
    if (theClass is HeapGraphClassActual) {
      final HeapGraphClassActual c = theClass;
      for (HeapSnapshotField field in c.origin.fields) {
        result.add(MapEntry(field.name, references[field.index]));
      }
    }
    return result;
  }

  @override
  String toString() {
    if (origin.data is HeapSnapshotObjectNoData) {
      return 'Instance of $theClass';
    }
    if (origin.data is HeapSnapshotObjectLengthData) {
      final HeapSnapshotObjectLengthData data = origin.data;
      return 'Instance of $theClass length = ${data.length}';
    }
    return 'Instance of $theClass; data: \'${origin.data}\'';
  }
}

abstract class HeapGraphClass {
  List<HeapGraphElement> _instances;
  List<HeapGraphElement> getInstances(HeapGraph graph) {
    if (_instances == null) {
      _instances = [];
      for (int i = 0; i < graph.elements.length; i++) {
        final HeapGraphElementActual converted = graph.elements[i];
        if (converted.theClass == this) {
          _instances.add(converted);
        }
      }
    }
    return _instances;
  }
}

class HeapGraphClassSentinel extends HeapGraphClass {
  @override
  String toString() => 'HeapGraphClassSentinel';
}

class HeapGraphClassActual extends HeapGraphClass {
  HeapGraphClassActual(this.origin) {
    _check();
  }

  void _check() {
    assert(origin != null);
  }

  final HeapSnapshotClass origin;

  String get name => origin.name;

  Uri get libraryUri => origin.libraryUri;

  @override
  String toString() => name;
}
