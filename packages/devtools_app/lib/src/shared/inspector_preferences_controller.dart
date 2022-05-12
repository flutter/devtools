import 'package:flutter/foundation.dart';

import '../../devtools_app.dart';

class InspectorPreferencesController {
  final ValueNotifier<bool> _hoverEvalMode = ValueNotifier(false);
  final String _hoverEvalModeStorageId = 'inspector.hoverEvalMode';

  ValueListenable<bool> get hoverEvalModeEnabled => _hoverEvalMode;

  Future<void> init() async {
    String? value = await storage.getValue(_hoverEvalModeStorageId);

    // When embedded, default hoverEvalMode to off
    value = await storage.getValue(_hoverEvalModeStorageId);
    value ??= (!ideTheme.embed).toString();
    toggleHoverEvalMode(value == 'true');

    _hoverEvalMode.addListener(() {
      storage.setValue(
        _hoverEvalModeStorageId,
        _hoverEvalMode.value.toString(),
      );
    });

    setGlobal(InspectorPreferencesController, this);
  }

  /// Change the value for the hover eval mode setting.
  void toggleHoverEvalMode(bool enableHoverEvalMode) {
    _hoverEvalMode.value = enableHoverEvalMode;
  }
}
