import 'package:html_shim/html.dart' as html;

import '../../src/ui/html_elements.dart';
import '../ui/fake_flutter/fake_flutter.dart';

class HtmlToolBarCheckbox {
  HtmlToolBarCheckbox(this.toolBarCheckboxDescription)
      : element = CoreElement('label') {
    final checkbox = CoreElement('input')..setAttribute('type', 'checkbox');
    _checkboxElement = checkbox.element;

    element.add(<CoreElement>[
      checkbox,
      span(text: ' ${toolBarCheckboxDescription.name}'),
    ]);

    _checkboxElement.checked = toolBarCheckboxDescription.enabled;
    valueNotifier.value = _checkboxElement.checked;
    _checkboxElement.onChange.listen((_) {
      final bool selected = _checkboxElement.checked;
      valueNotifier.value = selected;
    });
  }

  ValueNotifier<bool> valueNotifier = ValueNotifier<bool>(true);
  final ToolBarCheckboxDescription toolBarCheckboxDescription;
  final CoreElement element;
  html.InputElement _checkboxElement;
}

class ToolBarCheckboxDescription {
  ToolBarCheckboxDescription({this.name, this.enabled, this.tag});

  final String name;
  final String tag;
  final bool enabled;
}
