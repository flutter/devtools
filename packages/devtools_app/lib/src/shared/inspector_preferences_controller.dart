import 'package:flutter/foundation.dart';

import '../../devtools_app.dart';

class InspectorPreferencesController {
  final ValueNotifier<bool> _hoverEvalMode = ValueNotifier(ideTheme.embed);

  ValueListenable<bool> get hoverEvalModeEnabled => _hoverEvalMode;
  Future<void> init() async {
    String? value = await storage.getValue('ui.darkMode');

    value = await storage.getValue('ui.hoverEvalMode');
    toggleHoverEvalMode(value == 'true');
    _hoverEvalMode.addListener(() {
      storage.setValue('ui.hoverEvalMode', '${_hoverEvalMode.value}');
    });

    setGlobal(InspectorPreferencesController, this);
  }

  /// Change the value for the hover eval mode setting.
  void toggleHoverEvalMode(bool enableHoverEvalMode) {
    _hoverEvalMode.value = enableHoverEvalMode;
    VmServicePrivate.enablePrivateRpcs = enableHoverEvalMode; // What do?
  }
}
