// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' as html;

import '../globals.dart';
import '../service_extensions.dart';
import 'elements.dart';
import 'html_icon_renderer.dart';
import 'primer.dart';

const int defaultSplitterWidth = 12;

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
    ..add(CoreElement('label')..add([input, inputLabel]));
  input.setAttribute('title', extensionDescription.tooltip);
  return outerDiv;
}

class ServiceExtensionButton {
  ServiceExtensionButton(this.extensionDescription) {
    button = PButton.icon(
        extensionDescription.description, extensionDescription.icon,
        title: extensionDescription.tooltip)
      ..small();

    final extensionName = extensionDescription.extension;

    // Disable button for unavailable service extensions.
    button.disabled = !serviceManager.serviceExtensionManager
        .isServiceExtensionAvailable(extensionName);
    serviceManager.serviceExtensionManager.hasServiceExtension(
        extensionName, (available) => button.disabled = !available);

    button.click(() => click());

    _updateState();
  }

  final ServiceExtensionDescription extensionDescription;
  PButton button;

  void click() {
    final bool wasSelected = button.element.classes.contains('selected');
    serviceManager.serviceExtensionManager.setServiceExtensionState(
      extensionDescription.extension,
      !wasSelected,
      wasSelected
          ? extensionDescription.disabledValue
          : extensionDescription.enabledValue,
    );
  }

  void _updateState() {
    // Select button whose state is already enabled.
    serviceManager.serviceExtensionManager.getServiceExtensionState(
        extensionDescription.extension,
        (state) => button.toggleClass(
            'selected', state.value == extensionDescription.enabledValue));
  }
}
