//import 'package:devtools_app/src/ui/html_elements.dart';

import 'package:html_shim/html.dart' as html;

import '../../src/ui/html_elements.dart';
import 'config.dart';

class ToolBarCheckbox {
  ToolBarCheckbox(this.extensionDescription) : element = CoreElement('label') {
    final checkbox = CoreElement('input')..setAttribute('type', 'checkbox');
    _checkboxElement = checkbox.element;

    element.add(<CoreElement>[
      checkbox,
      span(text: ' ${extensionDescription.name}'),
    ]);

    _checkboxElement.checked = extensionDescription.enabled;
    _checkboxElement.onChange.listen((_) {
      final bool selected = _checkboxElement.checked;
      print('select = $selected');
      config[extensionDescription.tag] = selected;
    });
//    _updateState();
  }

  final ToolBarCheckboxDescription extensionDescription;
  final CoreElement element;
  html.InputElement _checkboxElement;

//  void _updateState() {
//    _checkboxElement.checked = config[extensionDescription.tag];
//  }
}

class ToolBarCheckboxDescription {
  ToolBarCheckboxDescription({this.name, this.enabled, this.tag});

  final String name;
  final String tag;
  final bool enabled;
}
