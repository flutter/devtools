import 'package:flutter/services.dart' show rootBundle;

import '../inspector_service.dart';

// Magic tokens to detect the start and the end of the block of code from the
// polyfill script to execute as an eval expression.
const _inspectorPolyfillStart = '// INSPECTOR_POLYFILL_SCRIPT_START\n';
const _inspectorPolyfillEnd = '// INSPECTOR_POLYFILL_SCRIPT_END\n';

Future<String> loadPolyfillScript() {
  return rootBundle.loadString('assets/scripts/inspector_polyfill_script.dart');
}

Future<void> invokeInspectorPolyfill(ObjectGroup group) async {
  final String script = await loadPolyfillScript();
  var startIndex = script.indexOf(_inspectorPolyfillStart);
  final endIndex = script.indexOf(_inspectorPolyfillEnd);
  if (startIndex == -1 || endIndex == -1) {
    throw Exception(
      '''Improperly formatted polyfill script. Expected to find expressions
$_inspectorPolyfillStart
and
$_inspectorPolyfillEnd

Script contents:
$script''',
    );
  }
  startIndex += _inspectorPolyfillStart.length;
  final polyFillScript = script.substring(startIndex, endIndex);
  final filteredLines = <String>[];
  // The Dart eval  does not support multiple line expressions so we have to strip out
  // line breaks.
  for (var line in polyFillScript.split('\n')) {
    line = line.trim();
    // Omit lines with // comments as they will confuse the single line eval
    // expression.
    if (!line.startsWith('//')) {
      filteredLines.add(line);
    }
  }

  final expression = '((){${filteredLines.join()}})()';

  await group.inspectorLibrary.eval(expression, isAlive: group);
}
