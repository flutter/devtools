# DevTools style guide

We fully follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
and some items of
[Style guide for Flutter repo](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo):

## Order of getters and setters

When an object owns and exposes a (listenable) value,
more complicated than just public field
we declare the related class members always in the same order,
in compliance with
[Flutter repo style guide]( https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#order-other-class-members-in-a-way-that-makes-sense):

1. Public getter
2. Private field
3. Public setter (when needed)

## Naming for typedefs and function variables

Follow [Flutter repo naming rules for typedefs and function variables](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#naming-rules-for-typedefs-and-function-variables).

## Overriding equality

Use [boilerplaite](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#common-boilerplates-for-operator--and-hashcode).

## Text styles

The default text style for DevTools is `Theme.of(context).regularTextStyle`. The default
value for `Theme.of(context).bodyMedium` is equivalent to `Theme.of(context).regularTextStyle`.

When creating a `Text` widget, this is the default style that will be applied.