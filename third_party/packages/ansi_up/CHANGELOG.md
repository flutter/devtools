## 2.0.0-dev
* Removed `AnsiUp.ansiColors` and `AnsiUp.palette256` members.

  These members were not useful to users, and they didn't need to be instance
  members. `ansiColors` is not a constant, and `palette256` is now initialized
  only once (instead of every time an `AnsiUp` is initialized).

## 1.0.0
* Migrate to null safety.

## 0.0.2
* Implemented `decodeAnsiColorEscapeCodes` in Dart - now no longer using JS
  interop.
