import 'package:devtools_app/devtools_app.dart';

class FakePreferencesController extends PreferencesController {
  @override
  InspectorPreferencesController get inspector {
    return _fakeInspectorPreferences;
  }

  final _fakeInspectorPreferences = FakeInspectorPreferencesController();
}

class FakeInspectorPreferencesController
    extends InspectorPreferencesController {
  @override
  Future<void> init() {
    return Future<void>.value();
  }

  @override
  Future<void> addPubRootDirectories(List<String> pubRootDirectories) {
    return Future<void>.value();
  }

  @override
  Future<void> removePubRootDirectories(List<String> pubRootDirectories) {
    return Future<void>.value();
  }

  @override
  Future<void> loadCustomPubRootDirectories() {
    return Future<void>.value();
  }
}
