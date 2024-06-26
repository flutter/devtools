# DevTools style guide

We fully follow [Effective Dart](https://dart.dev/effective-dart)
and some items of
[Style guide for Flutter repo](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md):

## Order of getters and setters

When an object owns and exposes a (listenable) value,
more complicated than just public field
we declare the related class members always in the same order,
without new lines separating the members,
in compliance with
[Flutter repo style guide](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md#order-other-class-members-in-a-way-that-makes-sense):

1. Public getter
2. Private field
3. Public setter (when needed)

## Naming for typedefs and function variables

Follow [Flutter repo naming rules for typedefs and function variables](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md#naming-rules-for-typedefs-and-function-variables).

## Overriding equality

Use [boilerplate](https://github.com/flutter/flutter/blob/master/docs/contributing/Style-guide-for-Flutter-repo.md#common-boilerplates-for-operator--and-hashcode).

## URIs and File Paths

Care should be taken when using file paths to ensure compatibility with both
Windows and POSIX style paths. File URIs should generally be preferred and only
converted to paths when required to interact with the file system.

`String` variables that hold paths or URIs should be named explicitly with a
`Path` or `Uri` suffix, such as `appRootPath` or `appRootUri`.

Additionally:

- `Uri.parse()` should not be used for converting file paths to URIs, instead
  `Uri.file()` should be used
- `Uri.path` should not be used for extracting a file path from a URI, instead
  `uri.toFilePath()` should be used
- In code compiled to run in the browser, `Uri.file()` and `uri.toFilePath()`
  will assume POSIX-style paths even on Windows, so care should be taken to
  handle these correctly (if possible, avoid converting between URIs and file
  paths in code running in a browser)

## Text styles

The default text style for DevTools is `Theme.of(context).regularTextStyle`. The default
value for `Theme.of(context).bodyMedium` is equivalent to `Theme.of(context).regularTextStyle`.

When creating a `Text` widget, this is the default style that will be applied.
