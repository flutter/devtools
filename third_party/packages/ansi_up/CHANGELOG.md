# 2.1.0
* Discontinue the `ansi_up` package.

## 2.0.0
* Fixed a regexp getting recompiled every time an `AnsiUp` is instantiated and
  `decodeAnsiColorEscapeCodes` is called for the first time.

  The regexp is now compiled once during the lifetime of the program.

* Removed `AnsiUp.ansiColors` and `AnsiUp.palette256` members.

  These members were not useful to users, and they didn't need to be instance
  members. `ansiColors` is not a constant, and `palette256` is now initialized
  only once (instead of every time an `AnsiUp` is initialized).

## 1.0.0
* Migrate to null safety.

## 0.0.2
* Implemented `decodeAnsiColorEscapeCodes` in Dart - now no longer using JS
  interop.
