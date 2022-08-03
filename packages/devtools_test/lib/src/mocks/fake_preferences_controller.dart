import 'package:devtools_app/devtools_app.dart';

import '../../devtools_test.dart';

class FakePreferencesController extends PreferencesController {
  @override
  InspectorPreferencesController get inspector {
    return _fakeInspectorPreferences;
  }

  final _fakeInspectorPreferences = MockInspectorPreferencesController();
}
