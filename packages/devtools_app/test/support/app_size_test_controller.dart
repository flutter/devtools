import 'package:devtools_app/src/app_size/app_size_controller.dart';
import 'package:devtools_app/src/utils.dart';

import 'utils.dart';

class AppSizeTestController extends AppSizeController {
  @override
  void loadTreeFromJsonFile(
    DevToolsJsonFile jsonFile,
    void Function(String error) onError, {
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadTreeFromJsonFile(jsonFile, onError);
  }

  @override
  void loadDiffTreeFromJsonFiles(
    DevToolsJsonFile oldFile,
    DevToolsJsonFile newFile,
    void Function(String error) onError, {
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadDiffTreeFromJsonFiles(oldFile, newFile, onError);
  }
}
