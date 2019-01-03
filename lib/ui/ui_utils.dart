// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import '../globals.dart';
import 'elements.dart';
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
  button.disabled = !serviceManager.serviceExtensionManager
      .isServiceExtensionAvailable(extensionName);
  serviceManager.serviceExtensionManager.hasServiceExtension(
      extensionName, (available) => button.disabled = !available);

  // Select button whose state is already enabled.
  serviceManager.serviceExtensionManager.getServiceExtensionState(
      extensionName, (state) => button.toggleClass('selected', state.enabled));

  return button;
}

CoreElement createExtensionCheckBox(String extensionName) {
  const String disabledTextColor = 'rgba(0, 0, 0, 0.3)';
  final CoreElement input = checkbox();
  final CoreElement text = span(text: extensionName);

  // Disable checkbox for unavailable service extensions.
  if (!serviceManager.serviceExtensionManager
      .isServiceExtensionAvailable(extensionName)) {
    input.disabled = true;
    text.element.style.color = disabledTextColor;
  }
  serviceManager.serviceExtensionManager.hasServiceExtension(extensionName,
      (available) {
    input.disabled = !available;
    text.element.style.color = available ? 'black' : disabledTextColor;
  });

  // Check box whose state is already enabled.
  serviceManager.serviceExtensionManager.getServiceExtensionState(extensionName,
      (state) {
    final html.InputElement e = input.element;
    e.checked = state.value;
  });

  input.element.onChange.listen((_) {
    final html.InputElement e = input.element;
    serviceManager.serviceExtensionManager
        .setServiceExtensionState(extensionName, e.checked, e.checked);
  });

  return div(c: 'form-checkbox')
    ..add(new CoreElement('label')
      ..add(<CoreElement>[
        input,
        text,
      ]));
}
