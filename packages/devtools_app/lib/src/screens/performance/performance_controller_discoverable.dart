import '../../../devtools_app.dart';
import '../../extensibility/discoverable.dart';

class DiscoverablePerformancePage extends DiscoverablePage {
  DiscoverablePerformancePage(this.controller) : super() {
    discoverableApp.performancePage = this;
  }

  final PerformanceController controller;

  static String get id => PerformanceScreen.id;

  // Events

  // Actions
  void selectFrame(int index) {
    controller.flutterFramesController.handleSelectedFrame(
      controller.flutterFramesController.flutterFrames.value[index],
    );
  }
}
