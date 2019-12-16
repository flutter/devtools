// TODO(terry): rename this library to file or something else with a followup CL.

export '_fake_file.dart'
    if (dart.library.io) '_real_file.dart'
    if (dart.library.html) '_fake_file.dart';
