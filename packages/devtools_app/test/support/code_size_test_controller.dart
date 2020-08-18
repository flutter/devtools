import 'package:devtools_app/src/code_size/code_size_controller.dart';
import 'package:devtools_app/src/utils.dart';

import 'utils.dart';

class CodeSizeTestController extends CodeSizeController {
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
