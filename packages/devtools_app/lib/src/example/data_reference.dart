// import 'package:flutter/material.dart';

// import '../trees.dart';

// enum DataType { Root, Library, Class, Method }

// class DataReference extends TreeNode<DataReference> {
//   DataReference({
//     @required this.name,
//     @required this.size,
//     @required this.dataType,
//   });

//   final String name;
//   final DataType dataType;
//   int size;

//   void addSize(int size) {
//     this.size += size;
//   }

//   DataReference getChildWithName(String name) {
//     return children.singleWhere(
//       (element) => element.name == name,
//       orElse: () {
//         return null;
//       },
//     );
//   }

//   void printTree() {
//     printTreeHelper(this, '');
//   }

//   void printTreeHelper(DataReference root, String tabs) {
//     print(tabs + '$root');
//     root.children.forEach((child) {
//       printTreeHelper(child, tabs + '\t');
//     });
//   }

//   @override
//   String toString() {
//     return '{name: $name, size: $size, dataType: $dataType}\n';
//   }
// }
