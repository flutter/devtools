import 'package:devtools_app/devtools_app.dart';

/// A [Storage] implementation that does not store state between instances.
///
/// This ephemeral implementation is meant to help keep unit tests segregated
class FlutterTestStorage implements Storage {
  late final Map<String, dynamic> _values = {};

  @override
  Future<String?> getValue(String key) async {
    return _values[key];
  }

  @override
  Future setValue(String key, String value) async {
    _values[key] = value;
  }
}
