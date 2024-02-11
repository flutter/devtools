import 'heap_data.dart';

class Heap {
  Heap(this.data);

  final HeapData data;
}

class HeapObject {
  HeapObject(this.data, {required this.index});

  final HeapData data;
  final int index;
}
