// // Copyright 2022 The Chromium Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style license that can be
// // found in the LICENSE file.

// import 'package:devtools_app/src/screens/memory/shared/heap/spanning_tree.dart';
// import 'package:devtools_app/src/shared/memory/adapted_heap_object.dart';
// import 'package:devtools_app/src/shared/memory/class_name.dart';
// import 'package:flutter_test/flutter_test.dart';

// void main() {
//   for (var t in _sizeTests) {
//     test('has expected root and unreachable sizes, ${t.name}.', () async {
//       await calculateHeap(t.heap);
//       expect(t.heap.root.retainedSize, equals(t.rootRetainedSize));

//       var actualUnreachableSize = 0;
//       for (var object in t.heap.objects) {
//         if (object.retainer == null) {
//           expect(object.retainedSize, isNull);
//           actualUnreachableSize += object.shallowSize;
//         }
//       }
//       expect(actualUnreachableSize, equals(t.unreachableSize));
//     });
//   }
// }

// final _sizeTests = [
//   // Heaps without unreachable objects:

//   _SizeTest(
//     name: 'One object heap',
//     heap: _heapData(
//       [
//         _createOneByteObject(0, []),
//       ],
//     ),
//     rootRetainedSize: 1,
//     unreachableSize: 0,
//   ),
//   _SizeTest(
//     name: 'Two objects heap',
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1]),
//         _createOneByteObject(1, []),
//       ],
//     ),
//     rootRetainedSize: 2,
//     unreachableSize: 0,
//   ),
//   _SizeTest(
//     name: 'Four objects heap',
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1, 2, 3]),
//         _createOneByteObject(1, []),
//         _createOneByteObject(2, []),
//         _createOneByteObject(3, []),
//       ],
//     ),
//     rootRetainedSize: 4,
//     unreachableSize: 0,
//   ),

//   // Heaps with unreachable objects:

//   _SizeTest(
//     name: 'One unreachable object heap',
//     heap: _heapData(
//       [
//         _createOneByteObject(0, []),
//         _createOneByteObject(1, []),
//       ],
//     ),
//     rootRetainedSize: 1,
//     unreachableSize: 1,
//   ),
//   _SizeTest(
//     name: 'Many unreachable objects heap',
//     heap: _heapData(
//       [
//         // Reachable:
//         _createOneByteObject(0, [1, 2, 3]),
//         _createOneByteObject(1, []),
//         _createOneByteObject(2, []),
//         _createOneByteObject(3, []),

//         // Unreachable:
//         _createOneByteObject(4, [5, 6, 7]),
//         _createOneByteObject(5, []),
//         _createOneByteObject(6, []),
//         _createOneByteObject(7, []),
//       ],
//     ),
//     rootRetainedSize: 4,
//     unreachableSize: 4,
//   ),

//   // Heaps with weak objects:
//   _SizeTest(
//     name: 'One weak object heap',
//     //  0
//     //  | \
//     //  1w 2
//     //  |
//     //  3
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1, 2]),
//         _createOneByteWeakObject(1, [3]),
//         _createOneByteObject(2, []),
//         _createOneByteObject(3, []),
//       ],
//     ),
//     rootRetainedSize: 3,
//     unreachableSize: 1,
//   ),
//   _SizeTest(
//     name: 'Two weak objects heap',
//     //  0
//     //  | \
//     //  1w 2w
//     //  |   \
//     //  3   4
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1, 2]),
//         _createOneByteWeakObject(1, [3]),
//         _createOneByteWeakObject(2, [4]),
//         _createOneByteObject(3, []),
//         _createOneByteObject(4, []),
//       ],
//     ),
//     rootRetainedSize: 3,
//     unreachableSize: 2,
//   ),

//   // Non-tree heaps.
//   _SizeTest(
//     name: 'Diamond',
//     //  |\
//     //  \|
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1, 2]),
//         _createOneByteObject(1, [3]),
//         _createOneByteObject(2, [3]),
//         _createOneByteObject(3, []),
//       ],
//     ),
//     rootRetainedSize: 4,
//     unreachableSize: 0,
//   ),
//   _SizeTest(
//     name: 'Hanged diamond',
//     //  \
//     //  |\
//     //  \|
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1]),
//         _createOneByteObject(1, [2, 3]),
//         _createOneByteObject(2, [4]),
//         _createOneByteObject(3, [4]),
//         _createOneByteObject(4, []),
//       ],
//     ),
//     rootRetainedSize: 5,
//     unreachableSize: 0,
//   ),
//   _SizeTest(
//     name: 'Hanged weak diamond',
//     //  \
//     //  |\
//     //  \|
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1]),
//         _createOneByteObject(1, [2, 3]),
//         _createOneByteWeakObject(2, [4]),
//         _createOneByteObject(3, [4]),
//         _createOneByteObject(4, []),
//       ],
//     ),
//     rootRetainedSize: 5,
//     unreachableSize: 0,
//   ),
//   _SizeTest(
//     name: 'Hanged very weak diamond',
//     //  \
//     //  |\
//     //  \|
//     heap: _heapData(
//       [
//         _createOneByteObject(0, [1]),
//         _createOneByteObject(1, [2, 3]),
//         _createOneByteWeakObject(2, [4]),
//         _createOneByteWeakObject(3, [4]),
//         _createOneByteObject(4, []),
//       ],
//     ),
//     rootRetainedSize: 4,
//     unreachableSize: 1,
//   ),
// ];

// class _SizeTest {
//   _SizeTest({
//     required this.name,
//     required this.heap,

//     /// Retained size of the root.
//     required this.rootRetainedSize,

//     /// Total size of all unreachable objects.
//     required this.unreachableSize,
//   }) : assert(_assertHeapIndexIsCode(heap));

//   final AdaptedHeapData heap;
//   final String name;
//   final int rootRetainedSize;
//   final int unreachableSize;
// }

// MockAdaptedHeapObject _createOneByteObject(
//   int codeAndIndex,
//   List<int> references,
// ) =>
//     MockAdaptedHeapObject(
//       code: codeAndIndex,
//       outRefs: references.toSet(),
//       heapClass: HeapClassName.fromPath(
//         className: 'MyClass',
//         library: 'my_lib',
//       ),
//       shallowSize: 1,
//     );

// MockAdaptedHeapObject _createOneByteWeakObject(
//   int codeAndIndex,
//   List<int> references,
// ) {
//   final result = MockAdaptedHeapObject(
//     code: codeAndIndex,
//     outRefs: references.toSet(),
//     heapClass: HeapClassName.fromPath(
//       className: '_WeakProperty',
//       library: 'dart.core',
//     ),
//     shallowSize: 1,
//   );
//   assert(result.heapClass.isWeakEntry, isTrue);
//   return result;
// }

// AdaptedHeapData _heapData(List<MockAdaptedHeapObject> objects) {
//   return AdaptedHeapData(objects, rootIndex: 0);
// }

// /// For convenience of testing each heap object has code equal to the
// /// index in array.
// bool _assertHeapIndexIsCode(AdaptedHeapData heap) => heap.objects
//     .asMap()
//     .entries
//     .every((entry) => entry.key == entry.value.code);
