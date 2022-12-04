import 'package:flutter/foundation.dart';

import '../../../devtools_app.dart';
import '../../analytics/constants.dart' as analytics_constants;
import '../../extensibility/discoverable.dart';
import 'memory_tabs.dart';

class DiscoverableMemoryPage extends DiscoverablePage {
  DiscoverableMemoryPage(this.controller) : super() {
    discoverableApp.memoryPage = this;
  }

  final MemoryController controller;

  static String get id => MemoryScreen.id;

  // Events
  static const memorySnapshotTaken = 'mem-snapshot-done';

  // Actions
  void takeSnapshotAction() {
    final takeSnapshot = controller.diffPaneController.takeSnapshotHandler(
      analytics_constants.MemoryEvent.diffTakeSnapshotControlPane,
    );
    if (takeSnapshot == null)
      print("takeSnapshotHandler returned null, can't take snapshot");
    else
      takeSnapshot();
  }

  void changeTabAction(Key tab) {
    controller.currentTab.value = tab;
  }

  static const dartHeapTableProfileTab =
      MemoryScreenKeys.dartHeapTableProfileTab;
  static const dartHeapAllocationTracingTab =
      MemoryScreenKeys.dartHeapAllocationTracingTab;
  static const diffTab = MemoryScreenKeys.diffTab;
  static const leaksTab = MemoryScreenKeys.leaksTab;
}
