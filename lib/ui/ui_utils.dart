import '../globals.dart';
import 'primer.dart';

// TODO(kenzie): perhaps add same icons we use in IntelliJ to these buttons.
// This would help to build icon familiarity.
PButton createExtensionButton(String text, String extensionName) {
  final PButton button = new PButton(text)..small();

  button.click(() {
    final bool wasSelected = button.element.classes.contains('selected');
    serviceManager.serviceExtensionManager
        .setServiceExtensionState(extensionName, !wasSelected, !wasSelected);
  });

  // Disable button for unavailable service extensions.
  serviceManager.serviceExtensionManager.hasServiceExtension(
      extensionName, (available) => button.disabled = !available);

  // Select button whose state is already enabled.
  serviceManager.serviceExtensionManager.getServiceExtensionState(
      extensionName, (state) => button.toggleClass('selected', state.enabled));

  return button;
}
