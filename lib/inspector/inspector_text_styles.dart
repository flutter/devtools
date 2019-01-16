import '../ui/fake_flutter/fake_flutter.dart';

final TextStyle grayed = TextStyle(color: Colors.grey.shade500);
const TextStyle regular = TextStyle(color: Colors.black);
final TextStyle warning = TextStyle(color: Colors.orange.shade500);
final TextStyle error = TextStyle(color: Colors.red.shade500);
final TextStyle link = TextStyle(
    color: Colors.blue.shade700, decoration: TextDecoration.underline);

const TextStyle regularBold =
    TextStyle(color: Colors.black, fontWeight: FontWeight.w700);
const TextStyle regularItalic =
    TextStyle(color: Colors.black, fontStyle: FontStyle.italic);

/// Pretty sames for common text styles to make it easier to debug output
/// containing these names.
final Map<TextStyle, String> debugStyleNames = {
  grayed: 'grayed',
  regular: '',
  warning: 'warning',
  error: 'error',
  link: 'link',
  regularBold: 'bold',
  regularItalic: 'italic',
};
