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
  return button;
}

CoreElement createExtensionCheckBox(String extensionName) {
  final CoreElement input = checkbox();

  serviceManager.serviceExtensionManager.hasServiceExtension(
      extensionName, (available) => input.disabled = !available);

  serviceManager.serviceExtensionManager.getServiceExtensionState(extensionName,
      (state) => input.toggleAttribute('checked', state.value ?? false));

  input.element.onChange.listen((_) {
    final html.InputElement e = input.element;
    serviceManager.serviceExtensionManager
        .setServiceExtensionState(extensionName, e.checked, e.checked);
  });

  return div(c: 'form-checkbox')
    ..add(new CoreElement('label')
      ..add(<CoreElement>[
        input,
        span(text: extensionName),
      ]));
}
