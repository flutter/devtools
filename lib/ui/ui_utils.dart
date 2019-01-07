// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;


import '../globals.dart';
import '../service_extensions.dart';
import 'elements.dart';
import 'html_icon_renderer.dart';
import 'primer.dart';

PButton createExtensionButton(
    ServiceExtensionDescription extensionDescription) {
  final PButton button = new PButton.icon(
      extensionDescription.description, extensionDescription.icon,
      title: extensionDescription.tooltip)
    ..small();

  final extensionName = extensionDescription.extension;

  button.click(() {
    final bool wasSelected = button.element.classes.contains('selected');
    serviceManager.serviceExtensionManager
        .setServiceExtensionState(extensionName, !wasSelected, !wasSelected);
  });

  // Disable button for unavailable service extensions.
  button.disabled = !serviceManager.serviceExtensionManager
      .isServiceExtensionAvailable(extensionName);
  serviceManager.serviceExtensionManager.hasServiceExtension(
      extensionName, (available) => button.disabled = !available);

  // Select button whose state is already enabled.
  serviceManager.serviceExtensionManager.getServiceExtensionState(
      extensionName, (state) => button.toggleClass('selected', state.enabled));

  return button;
}

CoreElement createExtensionCheckBox(
    ServiceExtensionDescription extensionDescription) {
  final extensionName = extensionDescription.extension;
  final CoreElement input = checkbox();

  serviceManager.serviceExtensionManager.hasServiceExtension(
      extensionName, (available) => input.disabled = !available);

  serviceManager.serviceExtensionManager.getServiceExtensionState(
    extensionName,
    (state) {
      final html.InputElement e = input.element;
      e.checked = state.value;
    },
  );

  input.element.onChange.listen((_) {
    final html.InputElement e = input.element;
    serviceManager.serviceExtensionManager
        .setServiceExtensionState(extensionName, e.checked, e.checked);
  });
  final inputLabel = label();
  if (extensionDescription.icon != null) {
    inputLabel.add(createIconElement(extensionDescription.icon));
  }
  inputLabel.add(span(text: extensionName));

  final outerDiv = div(c: 'form-checkbox')
    ..add(new CoreElement('label')..add([input, inputLabel]));
  input.setAttribute('title', extensionDescription.tooltip);
  return outerDiv;
}

// TODO(kenzie): add hotRestart button.

// TODO(kenzie): move method to more specific library.
CoreElement createHotReloadButton() {
  final PButton button = new PButton('Hot Reload')..small();
  button.click(() async {
    button.disabled = true;
    await serviceManager.performHotReload();
    button.disabled = false;
  });
  return button;
}
