import 'package:devtools_app/devtools_app.dart';
import 'package:devtools_app/src/shared/inspector_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_infra/flutter_test_storage.dart';

void main() {
  group('InspectorPreferencesController', () {
    group('hoverEvalMode', () {
      late InspectorPreferencesController controller;

      setUp(() async {
        setGlobal(Storage, FlutterTestStorage());
        setGlobal(IdeTheme, IdeTheme());
        controller = InspectorPreferencesController();
      });

      group('init', () {
        setUp(() {
          controller.toggleHoverEvalMode(false);
        });

        test('enables hover mode by default', () async {
          await controller.init();
          expect(controller.hoverEvalModeEnabled.value, isTrue);
        });

        test('when embedded, disables hover mode by default', () async {
          setGlobal(IdeTheme, IdeTheme(embed: true));
          await controller.init();
          expect(controller.hoverEvalModeEnabled.value, isFalse);
        });
      });

      test('can be updated', () async {
        await controller.init();

        var valueChanged = false;
        final newHoverModeValue = !controller.hoverEvalModeEnabled.value;
        controller.hoverEvalModeEnabled.addListener(() {
          valueChanged = true;
        });

        controller.toggleHoverEvalMode(newHoverModeValue);

        final storedHoverModeValue =
            await storage.getValue('inspector.hoverEvalMode');
        expect(valueChanged, isTrue);
        expect(controller.hoverEvalModeEnabled.value, newHoverModeValue);
        expect(
          storedHoverModeValue,
          newHoverModeValue.toString(),
        );
      });
    });
  });
}
