import 'package:devtools_app/src/app_size/app_size_controller.dart';
import 'package:devtools_app/src/utils.dart';
import 'package:flutter/widgets.dart';

import 'utils.dart';

class AppSizeTestController extends AppSizeController {
  @override
  void loadTreeFromJsonFile({
    @required DevToolsJsonFile jsonFile,
    @required void Function(String error) onError,
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadTreeFromJsonFile(jsonFile: jsonFile, onError: onError);
  }

  @override
  void loadDiffTreeFromJsonFiles({
    @required DevToolsJsonFile oldFile,
    @required DevToolsJsonFile newFile,
    @required void Function(String error) onError,
    bool delayed = false,
  }) async {
    if (delayed) {
      await delay();
    }
    super.loadDiffTreeFromJsonFiles(
        oldFile: oldFile, newFile: newFile, onError: onError);
  }
}
