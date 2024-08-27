## 1.0.1-dev
* Fixed a regexp getting recompiled every time an `AnsiUp` is instantiated and
  `decodeAnsiColorEscapeCodes` is called for the first time.

  The regexp is now compiled once during the lifetime of the program.

## 1.0.0
* Migrate to null safety.

## 0.0.2
* Implemented `decodeAnsiColorEscapeCodes` in Dart - now no longer using JS
  interop.
