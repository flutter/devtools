import 'dart:async';

import 'package:flutter/foundation.dart';

// TODO(jacobr): remove this class and port the rest of the code in DevTools to
// use ValueListenable directly instead of StreamBuilder.
/// A [ChangeNotifier] to help convert stream based code to use
/// [ValueListenable].
class StreamValueListenable<T> extends ChangeNotifier
    implements ValueListenable<T> {
  StreamValueListenable(this._onListen, this._lookupValue);

  StreamSubscription subscription;

  final StreamSubscription Function(StreamValueListenable<T> notifier)
      _onListen;
  final T Function() _lookupValue;

  // Cached last value that may be out of date if no listeners are attached.
  T _value;

  /// The current value stored in this notifier.
  ///
  /// When the value is replaced, this class notifies its listeners.
  @override
  T get value {
    if (!hasListeners) {
      _value = _lookupValue();
    }
    return _value;
  }

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      subscription = _onListen(this);
      _value = _lookupValue();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      subscription?.cancel();
      subscription = null;
    }
  }
}
