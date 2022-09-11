// GENERATED CODE - DO NOT MODIFY BY HAND

import 'package:stager/stager.dart';

// **************************************************************************
// StagerAppGenerator
// **************************************************************************

import 'offline.dart';

void main() {
  final scenes = [
    MemoryOfflineScene(),
  ];

  if (const String.fromEnvironment('Scene').isNotEmpty) {
    const sceneName = String.fromEnvironment('Scene');
    final scene = scenes.firstWhere((scene) => scene.title == sceneName);
    runStagerApp(scenes: [scene]);
  } else {
    runStagerApp(scenes: scenes);
  }
}
