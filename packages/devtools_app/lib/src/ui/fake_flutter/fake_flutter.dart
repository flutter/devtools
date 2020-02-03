// TODO(jacobr): rename this library to flutter with a followup CL.

export '_real_flutter.dart'
    if (dart.library.ui) '_real_flutter.dart'
    if (dart.library.html) '_fake_flutter.dart'
    if (dart.library.io) '_fake_flutter.dart'
    hide Element, required, visibleForTesting;
