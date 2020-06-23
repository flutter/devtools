// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import '../charts/treemap.dart';
import 'canned_data.dart';

class CodeSizeProcessor {
//   TreemapNode addChildNode(TreemapNode parent, String name, int byteSize) {
//     TreemapNode child = parent.childrenMap[name];
//     if (child == null) {
//       child = TreemapNode(
//         name: name,
//         byteSize: byteSize,
//         childrenMap: <String, TreemapNode>{},
//       );
//       parent.childrenMap[child.name] = child;
//       parent.addChild(child);
//     } else {
//       child.byteSize += byteSize;
//     }
//     return child;
//   }

//   TreemapNode buildTreeFromJson() {
//     final List data = jsonDecode(sizesJson);

//     final rootChildren = <String, TreemapNode>{};

//     final TreemapNode root = TreemapNode(
//       name: 'Root',
//       childrenMap: rootChildren,
//     );

//     for (Map<String, dynamic> memoryUsage in data) {
//       String libraryName = memoryUsage.lookUpWithDefault(
//         'l',
//         'Unnamed Library',
//       );
//       final className = memoryUsage.lookUpWithDefault('c', 'Unnamed Class');
//       final methodName = memoryUsage.lookUpWithDefault('n', 'Unnamed Method');
//       final byteSize = memoryUsage['s'];
//       if (byteSize == null) {
//         throw 'Size was null for $memoryUsage';
//       }
//       root.byteSize += byteSize;

//       TreemapNode libraryLevelChild;
//       if (libraryName.startsWith('package:flutter/src/')) {
//         final String package =
//             libraryName.replaceAll('package:flutter/src/', '');
//         final List<String> flutterPackageSplit = package.split('/');
//         libraryLevelChild = addChildNode(root, 'package:flutter', byteSize);
//         for (String level in flutterPackageSplit) {
//           libraryLevelChild = addChildNode(libraryLevelChild, level, byteSize);
//         }
//       } else {
//         libraryName = libraryName.split('/')[0];
//         libraryLevelChild = addChildNode(root, libraryName, byteSize);
//       }
//       final TreemapNode classLevelChild = addChildNode(
//         libraryLevelChild,
//         className,
//         byteSize,
//       );

//       addChildNode(
//         classLevelChild,
//         methodName,
//         byteSize,
//       );
//     }

//     return root;
//   }
}

extension DefaultMapGetter<K, V> on Map<K, V> {
  V lookUpWithDefault(K key, V defaultValue) {
    final value = this[key];
    if (_isStringObjectEmpty(value)) return defaultValue;
    return value;
  }

  bool _isStringObjectEmpty(V value) =>
      (value is String) ? value.isEmpty : true;
}
